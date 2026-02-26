import Foundation

// MARK: - CactusAgentSession

public final class CactusAgentSession: Sendable {
  private let observationRegistrar = _ObservationRegistrar()
  private let state: Lock<State>

  /// The underlying language model actor.
  public let languageModelActor: CactusLanguageModelActor

  private struct State {
    var transcript: CactusTranscript
    var isResponding: Bool
    var functions: [any CactusFunction]
    var delegate: (any Delegate)?
    var systemPrompt: CactusPromptContent?
  }

  /// The full history of interactions for this session.
  public var transcript: CactusTranscript {
    get {
      self.observationRegistrar.access(self, keyPath: \CactusAgentSession.transcript)
      return self.state.withLock { $0.transcript }
    }
    set {
      self.observationRegistrar.withMutation(of: self, keyPath: \CactusAgentSession.transcript) {
        self.state.withLock { $0.transcript = newValue }
      }
    }
  }

  /// A Boolean value indicating whether a response is currently being generated.
  public var isResponding: Bool {
    self.observationRegistrar.access(self, keyPath: \CactusAgentSession.isResponding)
    return self.state.withLock { $0.isResponding }
  }

  /// Functions available for tool-calling during completion.
  public var functions: [any CactusFunction] {
    get {
      self.observationRegistrar.access(self, keyPath: \CactusAgentSession.functions)
      return self.state.withLock { $0.functions }
    }
    set {
      self.observationRegistrar.withMutation(of: self, keyPath: \CactusAgentSession.functions) {
        self.state.withLock { $0.functions = newValue }
      }
    }
  }

  /// Delegate for customizing function call execution.
  public var delegate: (any Delegate)? {
    get { self.state.withLock { $0.delegate } }
    set { self.state.withLock { $0.delegate = newValue } }
  }

  private init(
    languageModelActor: CactusLanguageModelActor,
    functions: [any CactusFunction],
    transcript: CactusTranscript,
    systemPrompt: sending CactusPromptContent?
  ) {
    self.languageModelActor = languageModelActor
    self.state = Lock(
      State(
        transcript: transcript,
        isResponding: false,
        functions: functions,
        delegate: nil,
        systemPrompt: systemPrompt
      )
    )
  }
}

// MARK: - Initializers

extension CactusAgentSession {
  public enum AgentLoopError: Error {
    case missingFunction(String)
    case unsupportedFunctionInputSendability(String)
    case missingAssistantResponse
    case invalidUserMessage(String)
  }
  /// Creates a completion session from a language model and explicit transcript.
  ///
  /// - Parameters:
  ///   - model: The underlying language model.
  ///   - functions: Tool functions available to the session.
  ///   - transcript: The initial transcript to seed the session.
  public convenience init(
    model: consuming sending CactusLanguageModel,
    functions: [any CactusFunction] = [],
    transcript: CactusTranscript
  ) {
    self.init(
      languageModelActor: CactusLanguageModelActor(model: model),
      functions: functions,
      transcript: transcript,
      systemPrompt: nil
    )
  }

  /// Creates a completion session from a language model actor and explicit transcript.
  ///
  /// - Parameters:
  ///   - model: The underlying language model actor.
  ///   - functions: Tool functions available to the session.
  ///   - transcript: The initial transcript to seed the session.
  public convenience init(
    model: CactusLanguageModelActor,
    functions: [any CactusFunction] = [],
    transcript: CactusTranscript
  ) {
    self.init(
      languageModelActor: model,
      functions: functions,
      transcript: transcript,
      systemPrompt: nil
    )
  }

  /// Creates a completion session from a language model and system prompt.
  ///
  /// - Parameters:
  ///   - model: The underlying language model.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: The system prompt injected for the session.
  public convenience init(
    model: consuming sending CactusLanguageModel,
    functions: [any CactusFunction] = [],
    systemPrompt: sending CactusPromptContent
  ) {
    self.init(
      languageModelActor: CactusLanguageModelActor(model: model),
      functions: functions,
      transcript: CactusTranscript(),
      systemPrompt: systemPrompt
    )
  }

  /// Creates a completion session from a language model actor and system prompt.
  ///
  /// - Parameters:
  ///   - model: The underlying language model actor.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: The system prompt injected for the session.
  public convenience init(
    model: CactusLanguageModelActor,
    functions: [any CactusFunction] = [],
    systemPrompt: sending CactusPromptContent
  ) {
    self.init(
      languageModelActor: model,
      functions: functions,
      transcript: CactusTranscript(),
      systemPrompt: systemPrompt
    )
  }

  /// Creates a completion session from a language model and prompt builder.
  ///
  /// - Parameters:
  ///   - model: The underlying language model.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: A builder that produces the session's system prompt content.
  public convenience init(
    model: consuming sending CactusLanguageModel,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @Sendable () -> some CactusPromptRepresentable
  ) {
    let content: CactusPromptContent
    do {
      content = try systemPrompt().promptContent
    } catch {
      content = CactusPromptContent()
    }
    self.init(model: model, functions: functions, systemPrompt: content)
  }

  /// Creates a completion session from a language model actor and prompt builder.
  ///
  /// - Parameters:
  ///   - model: The underlying language model actor.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: A builder that produces the session's system prompt content.
  public convenience init(
    model: CactusLanguageModelActor,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @Sendable () -> some CactusPromptRepresentable
  ) {
    let content: CactusPromptContent
    do {
      content = try systemPrompt().promptContent
    } catch {
      content = CactusPromptContent()
    }
    self.init(model: model, functions: functions, systemPrompt: content)
  }
}

// MARK: - FunctionCall

extension CactusAgentSession {
  /// A function call failure that preserves the function call context.
  public struct FunctionThrow: Sendable {
    /// The function call that failed.
    public let functionCall: CactusAgentSession.FunctionCall

    /// The underlying thrown error.
    public let error: any Error

    /// Creates a function throw wrapper.
    public init(functionCall: CactusAgentSession.FunctionCall, error: any Error) {
      self.functionCall = functionCall
      self.error = error
    }
  }

  /// A function call output used for transcript tool response messages.
  public struct FunctionReturn {
    /// The function name.
    public let name: String

    /// The function output.
    public let content: CactusPromptContent

    /// Creates a function return value.
    public init(name: String, content: CactusPromptContent) {
      self.name = name
      self.content = content
    }
  }

  /// A resolved function call pairing a model-emitted call with a concrete registered function.
  public struct FunctionCall: Sendable {
    public enum Error: Swift.Error {
      case mismatchedFunctionName(expected: String, received: String)
    }

    /// The matched function instance.
    public let function: any CactusFunction

    /// The raw function call emitted by the language model.
    public let rawFunctionCall: CactusLanguageModel.FunctionCall

    /// Creates a resolved function call.
    public init(
      function: any CactusFunction,
      rawFunctionCall: CactusLanguageModel.FunctionCall
    ) throws {
      guard function.name == rawFunctionCall.name else {
        throw Error.mismatchedFunctionName(
          expected: function.name,
          received: rawFunctionCall.name
        )
      }

      self.function = function
      self.rawFunctionCall = rawFunctionCall
    }

    /// Decodes arguments from the raw function call payload.
    public func arguments<Arguments: Decodable>(
      decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder(),
      validator: JSONSchema.Validator = .shared
    ) throws -> Arguments {
      try self.function.decodeFunctionCallArguments(
        self.rawFunctionCall.arguments,
        as: Arguments.self,
        decoder: decoder,
        validator: validator
      )
    }

    /// Invokes the underlying function and returns prompt content output.
    public func invoke(
      decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder(),
      validator: JSONSchema.Validator = .shared
    ) async throws -> CactusPromptContent {
      try await self.function.invoke(
        rawArguments: self.rawFunctionCall.arguments,
        decoder: decoder,
        validator: validator
      )
    }
  }
}

extension CactusFunction {
  fileprivate func decodeFunctionCallArguments<Arguments: Decodable>(
    _ rawArguments: [String: JSONSchema.Value],
    as type: Arguments.Type,
    decoder: JSONSchema.Value.Decoder,
    validator: JSONSchema.Validator
  ) throws -> Arguments {
    try validator.validate(value: .object(rawArguments), with: self.parametersSchema)
    return try decoder.decode(type, from: .object(rawArguments))
  }
}

// MARK: - Delegate

extension CactusAgentSession {
  /// A delegate that customizes tool execution for a function-calling step.
  public protocol Delegate: Sendable {
    /// Executes resolved function calls and returns outputs in matching array order.
    ///
    /// - Parameters:
    ///   - session: The active session.
    ///   - functionCalls: The resolved function calls for the current model turn.
    /// - Returns: Function return outputs in the same order as `functionCalls`.
    func agentFunctionWillExecuteFunctions(
      _ session: CactusAgentSession,
      functionCalls: sending [CactusAgentSession.FunctionCall]
    ) async throws -> sending [CactusAgentSession.FunctionReturn]
  }
}

extension CactusAgentSession.Delegate {
  public func agentFunctionWillExecuteFunctions(
    _ session: CactusAgentSession,
    functionCalls: sending [CactusAgentSession.FunctionCall]
  ) async throws -> sending [CactusAgentSession.FunctionReturn] {
    try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: functionCalls)
  }
}

// MARK: - Parallel Function Call Executor

extension CactusAgentSession {
  /// An error thrown when one or more parallel function calls fail.
  public struct ExecuteParallelFunctionCallsError: Error {
    /// Collected failures from all function calls that threw.
    public let errors: [CactusAgentSession.FunctionThrow]
  }

  /// Executes function calls in parallel and returns ordered function outputs.
  public static func executeParallelFunctionCalls(
    functionCalls: sending [CactusAgentSession.FunctionCall]
  ) async throws -> sending [CactusAgentSession.FunctionReturn] {
    guard !functionCalls.isEmpty else { return [] }

    let collector = ErrorCollector()

    let results = await withTaskGroup(
      of: (Int, String, CactusPromptContent.MessageComponents)?.self,
      returning: [(Int, String, CactusPromptContent.MessageComponents)].self
    ) { group in
      for (index, functionCall) in functionCalls.enumerated() {
        group.addTask {
          do {
            let content = try await functionCall.invoke()
            let components = try content.messageComponents()
            return (index, functionCall.function.name, components)
          } catch {
            await collector.append(
              index: index,
              functionThrow: CactusAgentSession.FunctionThrow(
                functionCall: functionCall,
                error: error
              )
            )
            return nil
          }
        }
      }

      var results = [(Int, String, CactusPromptContent.MessageComponents)]()
      for await result in group {
        if let result {
          results.append(result)
        }
      }
      return results
    }

    var orderedReturns = [CactusAgentSession.FunctionReturn?](
      repeating: nil,
      count: functionCalls.count
    )
    for (index, name, components) in results {
      orderedReturns[index] = CactusAgentSession.FunctionReturn(
        name: name,
        content: CactusPromptContent {
          components.text
          CactusPromptContent(images: components.images)
        }
      )
    }

    try await collector.checkErrors()
    return orderedReturns.compactMap { $0 }
  }

  private actor ErrorCollector {
    private var indexedErrors = [(Int, CactusAgentSession.FunctionThrow)]()

    func append(index: Int, functionThrow: sending CactusAgentSession.FunctionThrow) {
      self.indexedErrors.append((index, functionThrow))
    }

    func checkErrors() throws {
      if !indexedErrors.isEmpty {
        throw ExecuteParallelFunctionCallsError(
          errors: self.indexedErrors
            .sorted { lhs, rhs in lhs.0 < rhs.0 }
            .map(\.1)
        )
      }
    }
  }
}

// MARK: - Control

extension CactusAgentSession {

  /// Stops any active generation on the underlying language model.
  nonisolated(nonsending) public func stop() async {
    await self.languageModelActor.stop()
  }

  /// Stops active generation, clears transcript state, and resets model context.
  nonisolated(nonsending) public func reset() async {
    await self.languageModelActor.stop()
    await self.languageModelActor.reset()
    self.transcript = CactusTranscript()
  }
}

// MARK: - Completion

extension CactusAgentSession {
  /// Performs one completion turn and returns a text output completion.
  ///
  /// - Parameter request: The user message request for this turn.
  /// - Returns: A completion containing the generated text output and new entries.
  @discardableResult
  nonisolated(nonsending) public func respond(
    to request: CactusUserMessage
  ) async throws -> CactusCompletion<String> {
    let stream = try self.stream(to: request)
    return try await withTaskCancellationHandler {
      try await stream.collectResponse()
    } onCancel: {
      stream.stop()
    }
  }

  /// Performs one completion turn and decodes structured output using an explicit schema.
  ///
  /// - Parameters:
  ///   - request: The user message request for this turn.
  ///   - outputType: The output type to decode.
  ///   - schema: The JSON schema used to constrain and validate generated output.
  ///   - validator: The validator used to validate generated JSON values.
  ///   - decoder: The decoder used to decode the validated JSON value into `Output`.
  /// - Returns: A completion containing structured output and new entries.
  @discardableResult
  nonisolated(nonsending) public func respond<Output: Decodable & Sendable>(
    to request: CactusUserMessage,
    generating outputType: Output.Type,
    schema: JSONSchema,
    validator: JSONSchema.Validator = .shared,
    decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder()
  ) async throws -> CactusCompletion<Output> {
    let stream = try self.stream(
      to: request,
      generating: outputType,
      schema: schema,
      validator: validator,
      decoder: decoder
    )
    return try await withTaskCancellationHandler {
      try await stream.collectResponse()
    } onCancel: {
      stream.stop()
    }
  }

  /// Performs one completion turn and decodes structured output for a `JSONGenerable` type.
  ///
  /// - Parameters:
  ///   - request: The user message request for this turn.
  ///   - outputType: The output type to decode.
  ///   - validator: The validator used to validate generated JSON values.
  ///   - decoder: The decoder used to decode the validated JSON value into `Output`.
  /// - Returns: A completion containing structured output and new entries.
  @discardableResult
  nonisolated(nonsending) public func respond<Output: JSONGenerable & Sendable>(
    to request: CactusUserMessage,
    generating outputType: Output.Type = Output.self,
    validator: JSONSchema.Validator = .shared,
    decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder()
  ) async throws -> CactusCompletion<Output> {
    try await self.respond(
      to: request,
      generating: outputType,
      schema: Output.jsonSchema,
      validator: validator,
      decoder: decoder
    )
  }
}

// MARK: - Streaming

extension CactusAgentSession {
  /// Streams plain-text tokens and returns completion entries and the final assistant response.
  ///
  /// - Parameter request: The user message request for this turn.
  /// - Returns: A stream whose final response is a completion containing generated text and entries.
  public func stream(
    to request: CactusUserMessage
  ) throws -> CactusInferenceStream<CactusCompletion<String>> {
    guard self.beginRespondingIfNecessary() else {
      throw CactusAgentSessionError.alreadyResponding
    }

    let context = self.streamRequestContext(from: request)

    self.state.withLock {
      guard $0.transcript.isEmpty, let prompt = $0.systemPrompt else {
        return
      }
      guard let text = try? prompt.messageComponents().text else {
        return
      }
      let systemMessage = CactusLanguageModel.ChatMessage.system(text)
      $0.transcript.insert(CactusTranscript.Element(message: systemMessage), at: 0)
    }

    let stream = CactusInferenceStream<CactusCompletion<String>> { continuation in
      defer { self.endResponding() }

      let userMessage = try context.userMessageResult.get()
      self.state.withLock { $0.transcript.append(CactusTranscript.Element(message: userMessage)) }

      var conversationMessages = self.transcript.messages
      var finalResponse = ""
      var completionEntries = [CactusCompletionEntry]()
      while true {
        let assistantStreamID = CactusGenerationID()
        let completedTurn = try await self.languageModelActor.complete(
          messages: conversationMessages,
          options: context.options,
          maxBufferSize: context.maxBufferSize,
          functions: context.functionDefinitions
        ) { token, tokenId in
          continuation.yield(
            token: CactusStreamedToken(
              messageStreamId: assistantStreamID,
              stringValue: token,
              tokenId: tokenId
            )
          )
        }

        let appendedMessages = Self.appendedMessages(
          in: completedTurn.messages,
          originalMessagesCount: conversationMessages.count
        )
        for message in appendedMessages {
          let transcriptEntry = CactusTranscript.Element(message: message)
          self.state.withLock { $0.transcript.append(transcriptEntry) }
          completionEntries.append(
            Self.completionEntry(
              transcriptEntry: transcriptEntry,
              completionMetrics: message.role == .assistant ? completedTurn.completion : nil
            )
          )
        }

        conversationMessages = self.transcript.messages
        finalResponse = completedTurn.completion.response

        if completedTurn.completion.functionCalls.isEmpty {
          break
        }

        let resolvedFunctionCalls = try self.resolveFunctionCalls(
          completedTurn.completion.functionCalls
        )
        let functionReturns: [CactusAgentSession.FunctionReturn]
        if let delegate = self.delegate {
          functionReturns = try await delegate.agentFunctionWillExecuteFunctions(
            self,
            functionCalls: resolvedFunctionCalls
          )
        } else {
          functionReturns = try await Self.executeParallelFunctionCalls(
            functionCalls: resolvedFunctionCalls
          )
        }

        let role = self.functionOutputRole()
        for functionReturn in functionReturns {
          let content = try Self.functionOutputPayload(
            name: functionReturn.name,
            content: functionReturn.content
          )
          let transcriptEntry = CactusTranscript.Element(
            message: CactusLanguageModel.ChatMessage(role: role, content: content)
          )
          self.state.withLock {
            $0.transcript.append(transcriptEntry)
          }
          completionEntries.append(Self.completionEntry(transcriptEntry: transcriptEntry))
        }

        conversationMessages = self.transcript.messages
      }

      guard !completionEntries.isEmpty else {
        throw AgentLoopError.missingAssistantResponse
      }
      return CactusCompletion(output: finalResponse, entries: completionEntries)
    }
    return stream
  }

  /// Streams structured output tokens and partials, then returns completion entries and output.
  ///
  /// - Parameters:
  ///   - request: The user message request for this turn.
  ///   - outputType: The structured output type to decode.
  ///   - configuration: The parser configuration used for structured streaming partials.
  /// - Returns: A stream whose final response is a completion containing decoded output and entries.
  public func stream<Output: JSONStreamGenerable & Sendable>(
    to request: CactusUserMessage,
    generating outputType: Output.Type = Output.self,
    configuration: JSONStreamParserConfiguration = JSONStreamParserConfiguration()
  ) throws -> CactusInferenceStream<CactusCompletion<Output>> where Output.Partial: Sendable {
    guard self.beginRespondingIfNecessary() else {
      throw CactusAgentSessionError.alreadyResponding
    }

    let context = self.streamRequestContext(from: request)
    let stream = CactusInferenceStream<CactusCompletion<Output>> { continuation in
      defer { self.endResponding() }

      let userMessage = try context.userMessageResult.get()
      let userTranscriptEntry = CactusTranscript.Element(message: userMessage)
      self.state.withLock { $0.transcript.append(userTranscriptEntry) }

      let transcriptCountBeforeTurn = self.transcript.count

      let assistantStreamID = CactusGenerationID()
      let completedTurn = try await self.languageModelActor.jsonStreamableComplete(
        messages: self.transcript.messages,
        as: outputType,
        configuration: configuration,
        options: CactusLanguageModel.JSONChatCompletionOptions(
          chatCompletionOptions: context.options
        ),
        maxBufferSize: context.maxBufferSize,
        functions: context.functionDefinitions
      ) { token, tokenId, partial in
        continuation.yield(
          token: CactusStreamedToken(
            messageStreamId: assistantStreamID,
            stringValue: token,
            tokenId: tokenId
          )
        )
        if let partial {
          continuation.yield(partial: partial)
        }
      }

      let appendedMessages = Self.appendedMessages(
        in: completedTurn.messages,
        originalMessagesCount: transcriptCountBeforeTurn
      )
      var completionEntries = [CactusCompletionEntry]()
      for message in appendedMessages {
        let transcriptEntry = CactusTranscript.Element(message: message)
        self.state.withLock { $0.transcript.append(transcriptEntry) }
        completionEntries.append(
          Self.completionEntry(
            transcriptEntry: transcriptEntry,
            completionMetrics: message.role == .assistant ? completedTurn.completion : nil
          )
        )
      }

      guard !completionEntries.isEmpty else {
        throw AgentLoopError.missingAssistantResponse
      }

      return CactusCompletion(
        output: try completedTurn.output.get(),
        entries: completionEntries
      )
    }
    return stream
  }

  /// Streams structured output tokens and returns completion entries and decoded output.
  ///
  /// - Parameters:
  ///   - request: The user message request for this turn.
  ///   - outputType: The structured output type to decode.
  ///   - schema: The JSON schema used to constrain and validate generated output.
  ///   - validator: The validator used to validate generated JSON values.
  ///   - decoder: The decoder used to decode the validated JSON value into `Output`.
  /// - Returns: A stream whose final response is a completion containing decoded output and entries.
  public func stream<Output: Decodable & Sendable>(
    to request: CactusUserMessage,
    generating outputType: Output.Type,
    schema: JSONSchema,
    validator: JSONSchema.Validator = .shared,
    decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder()
  ) throws -> CactusInferenceStream<CactusCompletion<Output>> {
    guard self.beginRespondingIfNecessary() else {
      throw CactusAgentSessionError.alreadyResponding
    }

    let context = self.streamRequestContext(from: request)
    let stream = CactusInferenceStream<CactusCompletion<Output>> { continuation in
      defer { self.endResponding() }

      let userMessage = try context.userMessageResult.get()
      self.state.withLock { $0.transcript.append(CactusTranscript.Element(message: userMessage)) }

      let transcriptCountBeforeTurn = self.transcript.count

      let assistantStreamID = CactusGenerationID()
      let completedTurn = try await self.languageModelActor.jsonComplete(
        messages: self.transcript.messages,
        as: outputType,
        schema: schema,
        options: CactusLanguageModel.JSONChatCompletionOptions(
          chatCompletionOptions: context.options,
          validator: validator,
          decoder: decoder
        ),
        maxBufferSize: context.maxBufferSize,
        functions: context.functionDefinitions
      ) { token, tokenId in
        continuation.yield(
          token: CactusStreamedToken(
            messageStreamId: assistantStreamID,
            stringValue: token,
            tokenId: tokenId
          )
        )
      }

      let appendedMessages = Self.appendedMessages(
        in: completedTurn.messages,
        originalMessagesCount: transcriptCountBeforeTurn
      )
      var completionEntries = [CactusCompletionEntry]()
      for message in appendedMessages {
        let transcriptEntry = CactusTranscript.Element(message: message)
        self.state.withLock { $0.transcript.append(transcriptEntry) }
        completionEntries.append(
          Self.completionEntry(
            transcriptEntry: transcriptEntry,
            completionMetrics: message.role == .assistant ? completedTurn.completion : nil
          )
        )
      }

      guard !completionEntries.isEmpty else {
        throw AgentLoopError.missingAssistantResponse
      }

      return CactusCompletion(
        output: try completedTurn.output.get(),
        entries: completionEntries
      )
    }
    return stream
  }
}

// MARK: - Agent Loop Helpers

extension CactusAgentSession {
  private func beginRespondingIfNecessary() -> Bool {
    self.observationRegistrar.withMutation(of: self, keyPath: \CactusAgentSession.isResponding) {
      self.state.withLock { state in
        guard !state.isResponding else { return false }
        state.isResponding = true
        return true
      }
    }
  }

  private func endResponding() {
    self.observationRegistrar.withMutation(of: self, keyPath: \CactusAgentSession.isResponding) {
      self.state.withLock { state in
        guard state.isResponding else { return }
        state.isResponding = false
      }
    }
  }

  private static func completionEntry(
    transcriptEntry: CactusTranscript.Element,
    completionMetrics: CactusLanguageModel.ChatCompletion? = nil
  ) -> CactusCompletionEntry {
    if let completionMetrics {
      return CactusCompletionEntry(
        transcriptEntry: transcriptEntry,
        prefillTokens: completionMetrics.prefillTokens,
        decodeTokens: completionMetrics.decodeTokens,
        totalTokens: completionMetrics.totalTokens,
        confidence: completionMetrics.confidence,
        prefillTps: completionMetrics.prefillTps,
        decodeTps: completionMetrics.decodeTps,
        ramUsageMb: completionMetrics.ramUsageMb,
        durationToFirstToken: .seconds(completionMetrics.timeIntervalToFirstToken),
        totalDuration: .seconds(completionMetrics.totalTimeInterval)
      )
    }

    return CactusCompletionEntry(
      transcriptEntry: transcriptEntry,
      prefillTokens: 0,
      decodeTokens: 0,
      totalTokens: 0,
      confidence: 0,
      prefillTps: 0,
      decodeTps: 0,
      ramUsageMb: 0,
      durationToFirstToken: .seconds(0),
      totalDuration: .seconds(0)
    )
  }

  private func resolveFunctionCalls(
    _ functionCalls: [CactusLanguageModel.FunctionCall]
  ) throws -> [CactusAgentSession.FunctionCall] {
    let availableFunctions = self.functions
    return try functionCalls.map { functionCall in
      guard let function = availableFunctions.first(where: { $0.name == functionCall.name }) else {
        throw AgentLoopError.missingFunction(functionCall.name)
      }
      return try CactusAgentSession.FunctionCall(function: function, rawFunctionCall: functionCall)
    }
  }

  private func chatOptions(
    from request: CactusUserMessage
  ) -> CactusLanguageModel.ChatCompletion.Options {
    let maxTokens: Int
    switch request.maxTokens {
    case .limit(let limit):
      maxTokens = limit
    case .engineBehavior:
      maxTokens = 512
    }

    return CactusLanguageModel.ChatCompletion.Options(
      maxTokens: maxTokens,
      temperature: request.temperature,
      topP: request.topP,
      topK: request.topK,
      stopSequences: request.stopSequences,
      forceFunctions: request.forceFunctions,
      confidenceThreshold: 0, // TODO: Support cloud handoff in delegate.
      toolRagTopK: request.toolRagTopK,
      includeStopSequences: request.includeStopSequences,
      isTelemetryEnabled: request.isTelemetryEnabled
    )
  }

  private func functionOutputRole() -> CactusLanguageModel.MessageRole {
    let modelType = self.languageModelActor.configurationFile.modelType
    if modelType == .qwen {
      return CactusLanguageModel.MessageRole(rawValue: "function")
    }
    return CactusLanguageModel.MessageRole(rawValue: "tool")
  }

  private struct StreamRequestContext: Sendable {
    let userMessageResult: Result<CactusLanguageModel.ChatMessage, AgentLoopError>
    let options: CactusLanguageModel.ChatCompletion.Options
    let maxBufferSize: Int?
    let functionDefinitions: [CactusLanguageModel.FunctionDefinition]
  }

  private func streamRequestContext(
    from request: CactusUserMessage
  ) -> StreamRequestContext {
    let userMessageResult: Result<CactusLanguageModel.ChatMessage, AgentLoopError>
    do {
      userMessageResult = .success(try Self.userChatMessage(from: request))
    } catch {
      userMessageResult = .failure(.invalidUserMessage(String(describing: error)))
    }

    return StreamRequestContext(
      userMessageResult: userMessageResult,
      options: self.chatOptions(from: request),
      maxBufferSize: request.maxBufferSize,
      functionDefinitions: self.functions.map(\.definition)
    )
  }

  private static func userChatMessage(
    from request: CactusUserMessage
  ) throws -> CactusLanguageModel.ChatMessage {
    let components = try request.content.messageComponents()
    return CactusLanguageModel.ChatMessage.user(components.text, images: components.images)
  }

  private static func appendedMessages(
    in messages: [CactusLanguageModel.ChatMessage],
    originalMessagesCount: Int
  ) -> [CactusLanguageModel.ChatMessage] {
    if messages.count <= originalMessagesCount {
      return []
    }
    return Array(messages.dropFirst(originalMessagesCount))
  }

  private static func functionOutputPayload(
    name: String,
    content: CactusPromptContent
  ) throws -> String {
    struct Payload: Encodable {
      let name: String
      let content: String
    }

    let components = try content.messageComponents()
    let data = try JSONEncoder().encode(Payload(name: name, content: components.text))
    return String(decoding: data, as: UTF8.self)
  }
}

/// An error thrown by ``CactusAgentSession`` APIs.
public struct CactusAgentSessionError: Error, Hashable, Sendable {
  /// A human-readable description of the failure.
  public let message: String

  private init(message: String) {
    self.message = message
  }

  /// A request was sent while another response stream was still active.
  public static let alreadyResponding = Self(
    message: "The agent is already responding to another request."
  )
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgentSession: _Observable {}
