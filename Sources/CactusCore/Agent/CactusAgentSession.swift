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
    systemPrompt _: CactusPromptContent?
  ) {
    self.languageModelActor = languageModelActor
    self.state = Lock(
      State(
        transcript: transcript,
        isResponding: false,
        functions: functions,
        delegate: nil
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
    systemPrompt: CactusPromptContent
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
    systemPrompt: CactusPromptContent
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
    private let invoker: any FunctionCallInvoker

    /// The raw function call emitted by the language model.
    public let rawFunctionCall: CactusLanguageModel.FunctionCall

    /// Creates a resolved function call.
    public init<Function: CactusFunction & Sendable>(
      function: Function,
      rawFunctionCall: CactusLanguageModel.FunctionCall
    ) throws where Function.Input: Sendable {
      guard function.name == rawFunctionCall.name else {
        throw Error.mismatchedFunctionName(
          expected: function.name,
          received: rawFunctionCall.name
        )
      }

      self.function = function
      self.invoker = ConcreteFunctionCallInvoker(function: function)
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
      try await self.invoker.invoke(
        self.rawFunctionCall.arguments,
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

private protocol FunctionCallInvoker: Sendable {
  func invoke(
    _ rawArguments: [String: JSONSchema.Value],
    decoder: JSONSchema.Value.Decoder,
    validator: JSONSchema.Validator
  ) async throws -> CactusPromptContent
}

private struct ConcreteFunctionCallInvoker<Function: CactusFunction & Sendable>: FunctionCallInvoker
where Function.Input: Sendable {
  let function: Function

  func invoke(
    _ rawArguments: [String: JSONSchema.Value],
    decoder: JSONSchema.Value.Decoder,
    validator: JSONSchema.Validator
  ) async throws -> CactusPromptContent {
    let input = try self.function.decodeFunctionCallArguments(
      rawArguments,
      as: Function.Input.self,
      decoder: decoder,
      validator: validator
    )
    let output = try await self.function.invoke(input: consume input)
    return try output.promptContent
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
    fatalError("Not implemented")
  }

  /// Stops active generation, clears transcript state, and resets model context.
  nonisolated(nonsending) public func reset() async {
    fatalError("Not implemented")
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
    fatalError("Not implemented")
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
    fatalError("Not implemented")
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
    fatalError("Not implemented")
  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgentSession: _Observable {}
