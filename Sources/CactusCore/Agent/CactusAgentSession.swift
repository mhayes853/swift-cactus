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
        functions: functions
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
