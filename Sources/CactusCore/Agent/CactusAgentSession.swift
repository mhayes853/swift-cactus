import Foundation

// MARK: - CactusAgentSession

/// A class for agent workflows using Cactus inference.
///
///
public final class CactusAgentSession: Sendable {
  private let observationRegistrar = _ObservationRegistrar()
  private let state: Lock<State>

  /// The underlying language model actor.
  public let languageModelActor: CactusModelActor

  private struct State {
    var transcript: CactusTranscript
    var isResponding: Bool
    var activeStreamStopper: (@Sendable () -> Void)?
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
    languageModelActor: CactusModelActor,
    functions: [any CactusFunction],
    transcript: CactusTranscript,
    systemPrompt: sending CactusPromptContent?
  ) {
    self.languageModelActor = languageModelActor
    self.state = Lock(
      State(
        transcript: transcript,
        isResponding: false,
        activeStreamStopper: nil,
        functions: functions,
        delegate: nil,
        systemPrompt: systemPrompt
      )
    )
  }
}

// MARK: - Initializers

extension CactusAgentSession {
  /// Creates a completion session from a language model and explicit transcript.
  ///
  /// - Parameters:
  ///   - model: The underlying language model.
  ///   - functions: Tool functions available to the session.
  ///   - transcript: The initial transcript to seed the session.
  public convenience init(
    model: consuming sending CactusModel,
    functions: [any CactusFunction] = [],
    transcript: CactusTranscript
  ) {
    self.init(
      languageModelActor: CactusModelActor(model: model),
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
    model: CactusModelActor,
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
    model: consuming sending CactusModel,
    functions: [any CactusFunction] = [],
    systemPrompt: sending CactusPromptContent
  ) {
    self.init(
      languageModelActor: CactusModelActor(model: model),
      functions: functions,
      transcript: CactusTranscript(),
      systemPrompt: systemPrompt
    )
  }

  /// Creates a completion session from a model URL.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  ///   - functions: Tool functions available to the session.
  ///   - transcript: The initial transcript to seed the session.
  public convenience init(
    from url: URL,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false,
    functions: [any CactusFunction] = [],
    transcript: CactusTranscript = CactusTranscript()
  ) throws {
    let model = try CactusModel(
      from: url,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
    self.init(
      model: model,
      functions: functions,
      transcript: transcript
    )
  }

  /// Creates a completion session from a model URL with a system prompt.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: The system prompt injected for the session.
  public convenience init(
    from url: URL,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false,
    functions: [any CactusFunction] = [],
    systemPrompt: sending CactusPromptContent
  ) throws {
    let model = try CactusModel(
      from: url,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
    self.init(
      model: model,
      functions: functions,
      systemPrompt: systemPrompt
    )
  }

  /// Creates a completion session from a model URL and prompt builder.
  ///
  /// - Parameters:
  ///   - url: The local `URL` of the model.
  ///   - corpusDirectoryURL: A `URL` to a corpus directory of documents for RAG models.
  ///   - cacheIndex: Whether to load a cached RAG index if available.
  ///   - functions: Tool functions available to the session.
  ///   - transcript: The initial transcript to seed the session.
  ///   - systemPrompt: A builder that produces the session's system prompt content.
  public convenience init(
    from url: URL,
    corpusDirectoryURL: URL? = nil,
    cacheIndex: Bool = false,
    functions: [any CactusFunction] = [],
    transcript: CactusTranscript = CactusTranscript(),
    @CactusPromptBuilder systemPrompt: @Sendable () -> some CactusPromptRepresentable
  ) throws {
    let model = try CactusModel(
      from: url,
      corpusDirectoryURL: corpusDirectoryURL,
      cacheIndex: cacheIndex
    )
    self.init(
      languageModelActor: CactusModelActor(model: model),
      functions: functions,
      transcript: transcript,
      systemPrompt: CactusPromptContent(systemPrompt())
    )
  }

  /// Creates a completion session from a model URL and prompt builder.
  ///
  /// - Parameters:
  ///   - model: The underlying language model actor.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: The system prompt injected for the session.
  public convenience init(
    model: CactusModelActor,
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
    model: consuming sending CactusModel,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(model: model, functions: functions, systemPrompt: CactusPromptContent(systemPrompt()))
  }

  /// Creates a completion session from a language model actor and prompt builder.
  ///
  /// - Parameters:
  ///   - model: The underlying language model actor.
  ///   - functions: Tool functions available to the session.
  ///   - systemPrompt: A builder that produces the session's system prompt content.
  public convenience init(
    model: CactusModelActor,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: @Sendable () -> some CactusPromptRepresentable
  ) {
    self.init(model: model, functions: functions, systemPrompt: CactusPromptContent(systemPrompt()))
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
    /// The matched function instance.
    public let function: any CactusFunction

    /// The arguments that the function was invoked with.
    public let arguments: [String: JSONSchema.Value]

    /// Creates a resolved function call.
    public init(
      function: any CactusFunction,
      arguments: [String: JSONSchema.Value]
    ) {
      self.function = function
      self.arguments = arguments
    }

    /// Decodes arguments from the raw function call payload.
    public func arguments<Arguments: Decodable>(
      decoder: JSONSchema.Value.Decoder = JSONSchema.Value.Decoder(),
      validator: JSONSchema.Validator = .shared
    ) throws -> Arguments {
      try self.function.decodeFunctionCallArguments(
        self.arguments,
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
        rawArguments: self.arguments,
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

    let results = try await withThrowingTaskGroup(
      of: (Int, String, CactusPromptContent.MessageComponents)?.self,
      returning: [(Int, String, CactusPromptContent.MessageComponents)].self
    ) { group in
      for (index, functionCall) in functionCalls.enumerated() {
        group.addTask {
          do {
            let content = try await functionCall.invoke()
            let components = try content.messageComponents()
            return (index, functionCall.function.name, components)
          } catch is CancellationError {
            throw CancellationError()
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
      for try await result in group {
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
    self.stopActiveStreamIfNecessary()
    self.endResponding()
    await self.languageModelActor.stop()
  }

  /// Stops active generation, clears transcript state, and resets model context.
  nonisolated(nonsending) public func reset() async {
    self.stopActiveStreamIfNecessary()
    self.endResponding()
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
      self.endResponding()
    }
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

    let context: StreamRequestContext
    do {
      context = try self.streamRequestContext(from: request)
      try self.insertSystemPromptIfNecessary()
    } catch {
      self.endResponding()
      throw error
    }

    let stream = CactusInferenceStream<CactusCompletion<String>> { continuation in
      defer { self.endResponding() }

      var completionEntries = [CactusCompletionEntry]()

      let initialTranscriptCount = self.transcript.count

      self.appendTranscriptEntry(
        context.transcript.last!,
        metrics: nil,
        completionEntries: &completionEntries
      )

      var conversationMessages = context.transcript
      var finalResponse = ""
      do {
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

          let appendedMessages = self.appendedMessages(
            in: completedTurn.messages,
            originalMessagesCount: conversationMessages.count
          )
          self.appendModelMessages(
            appendedMessages,
            completion: completedTurn.completion,
            completionEntries: &completionEntries
          )

          conversationMessages = context.transcript
          finalResponse = completedTurn.completion.response

          if completedTurn.completion.functionCalls.isEmpty {
            break
          }

          let resolvedFunctionCalls = try self.resolveFunctionCalls(
            completedTurn.completion.functionCalls,
            using: context.functions
          )
          let functionReturns = try await self.executeFunctionCalls(resolvedFunctionCalls)

          try self.appendFunctionReturns(
            functionReturns,
            role: .tool,
            completionEntries: &completionEntries
          )

          conversationMessages = context.transcript
        }
      } catch {
        self.removeTranscriptEntriesSince(initialCount: initialTranscriptCount)
        throw error
      }
      return CactusCompletion(output: finalResponse, entries: completionEntries)
    }
    self.registerActiveStreamStopper(stream)
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

  private func registerActiveStreamStopper<Output>(_ stream: CactusInferenceStream<Output>)
  where Output: Sendable {
    self.state.withLock { $0.activeStreamStopper = { stream.stop() } }
  }

  private func stopActiveStreamIfNecessary() {
    let activeStreamStopper = self.state.withLock { state in
      let stopper = state.activeStreamStopper
      state.activeStreamStopper = nil
      return stopper
    }
    activeStreamStopper?()
  }

  private func endResponding() {
    self.observationRegistrar.withMutation(of: self, keyPath: \CactusAgentSession.isResponding) {
      self.state.withLock { state in
        state.activeStreamStopper = nil
        guard state.isResponding else { return }
        state.isResponding = false
      }
    }
  }

  private func resolveFunctionCalls(
    _ functionCalls: [CactusModel.FunctionCall],
    using functions: [any CactusFunction]
  ) throws -> [CactusAgentSession.FunctionCall] {
    return try functionCalls.map { functionCall in
      guard let function = functions.first(where: { $0.name == functionCall.name }) else {
        throw CactusAgentSessionError.missingFunction(functionCall.name)
      }
      return CactusAgentSession.FunctionCall(
        function: function,
        arguments: functionCall.arguments
      )
    }
  }

  private struct StreamRequestContext: Sendable {
    let transcript: [CactusModel.ChatMessage]
    let options: CactusModel.Completion.Options
    let maxBufferSize: Int?
    let functionDefinitions: [CactusModel.FunctionDefinition]
    let functions: [any CactusFunction]
  }

  private func streamRequestContext(
    from request: CactusUserMessage
  ) throws -> StreamRequestContext {
    let userMessage: CactusModel.ChatMessage
    do {
      userMessage = try self.userChatMessage(from: request)
    } catch {
      throw CactusAgentSessionError.invalidUserMessage(error)
    }

    var transcript = self.transcript.messages
    transcript.append(userMessage)

    return StreamRequestContext(
      transcript: transcript,
      options: CactusModel.Completion.Options(message: request),
      maxBufferSize: request.maxBufferSize,
      functionDefinitions: self.functions.map(\.definition),
      functions: self.functions
    )
  }

  private func insertSystemPromptIfNecessary() throws {
    let prompt: CactusPromptContent? = self.state.withLock { state in
      if state.transcript.isEmpty {
        return state.systemPrompt
      }
      return Optional<CactusPromptContent>.none
    }
    guard let prompt else { return }

    let text: String
    do {
      let components = try prompt.messageComponents()
      text = components.text
    } catch {
      throw CactusAgentSessionError.invalidSystemPrompt(error)
    }

    let systemMessage = CactusModel.ChatMessage.system(text)
    self.state.withLock { state in
      guard state.transcript.isEmpty else { return }
      state.transcript.insert(CactusTranscript.Element(message: systemMessage), at: 0)
    }
  }

  private func appendTranscriptEntry(
    _ message: CactusModel.ChatMessage,
    metrics: CactusGenerationMetrics?,
    completionEntries: inout [CactusCompletionEntry]
  ) {
    let transcriptEntry = CactusTranscript.Element(message: message)
    self.transcript.append(transcriptEntry)
    completionEntries.append(
      CactusCompletionEntry(transcriptEntry: transcriptEntry, metrics: metrics)
    )
  }

  private func removeUserMessageFromTranscript() {
    guard let lastElement = self.transcript.last,
          lastElement.message.role == .user else {
      return
    }
    _ = self.transcript.removeElement(at: self.transcript.count - 1)
  }

  private func removeTranscriptEntriesSince(initialCount: Int) {
    while self.transcript.count > initialCount {
      _ = self.transcript.removeElement(at: self.transcript.count - 1)
    }
  }

  private func appendModelMessages(
    _ messages: [CactusModel.ChatMessage],
    completion: CactusModel.Completion,
    completionEntries: inout [CactusCompletionEntry]
  ) {
    for message in messages {
      let metrics: CactusGenerationMetrics? = message.role == .assistant
        ? CactusGenerationMetrics(completion: completion)
        : nil
      self.appendTranscriptEntry(
        message,
        metrics: metrics,
        completionEntries: &completionEntries
      )
    }
  }

  private func executeFunctionCalls(
    _ functionCalls: [CactusAgentSession.FunctionCall]
  ) async throws -> [CactusAgentSession.FunctionReturn] {
    if let delegate = self.delegate {
      return try await delegate.agentFunctionWillExecuteFunctions(
        self,
        functionCalls: functionCalls
      )
    }
    return try await Self.executeParallelFunctionCalls(functionCalls: functionCalls)
  }

  private func appendFunctionReturns(
    _ functionReturns: [CactusAgentSession.FunctionReturn],
    role: CactusModel.MessageRole,
    completionEntries: inout [CactusCompletionEntry]
  ) throws {
    for functionReturn in functionReturns {
      let content = try self.functionOutputPayload(
        name: functionReturn.name,
        content: functionReturn.content
      )
      self.appendTranscriptEntry(
        CactusModel.ChatMessage(role: role, content: content),
        metrics: nil,
        completionEntries: &completionEntries
      )
    }
  }

  private func userChatMessage(
    from request: CactusUserMessage
  ) throws -> CactusModel.ChatMessage {
    let components = try request.content.messageComponents()
    return CactusModel.ChatMessage.user(components.text, images: components.images)
  }

  private func appendedMessages(
    in messages: [CactusModel.ChatMessage],
    originalMessagesCount: Int
  ) -> [CactusModel.ChatMessage] {
    if messages.count <= originalMessagesCount {
      return []
    }
    return Array(messages.dropFirst(originalMessagesCount))
  }

  private func functionOutputPayload(
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
public struct CactusAgentSessionError: Error, Sendable {
  /// The underlying error that caused this error, if any.
  public let underlyingError: (any Error)?

  private let _message: String?

  /// A human-readable description of the failure.
  public var message: String {
    if let error = self.underlyingError {
      return error.localizedDescription
    }
    return self._message ?? "Unknown error"
  }

  private init(message: String) {
    self.underlyingError = nil
    self._message = message
  }

  private init(error: any Error) {
    self.underlyingError = error
    self._message = nil
  }

  /// A request was sent while another response stream was still active.
  public static let alreadyResponding = Self(
    message: "The agent is already responding to another request."
  )

  /// A model-emitted function call referenced a function that is not registered.
  public static func missingFunction(_ name: String) -> Self {
    Self(message: "Missing function for model-emitted call: \(name)")
  }

  /// User message content could not be converted to a chat message.
  ///
  /// - Parameter error: The underlying error that caused the conversion to fail.
  public static func invalidUserMessage(_ error: any Error) -> Self {
    Self(error: error)
  }

  /// System prompt content could not be converted to a chat message.
  ///
  /// - Parameter error: The underlying error that caused the conversion to fail.
  public static func invalidSystemPrompt(_ error: any Error) -> Self {
    Self(error: error)
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgentSession: _Observable {}
