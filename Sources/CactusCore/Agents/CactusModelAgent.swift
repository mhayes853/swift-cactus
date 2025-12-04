import Foundation

// MARK: - CactusModelAgent

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
>: CactusAgent {
  private let access: AgentModelAccess
  private let transcript: CactusTranscript

  public init(_ model: CactusLanguageModel, transcript: CactusTranscript) {
    self.init(access: .direct(model), transcript: transcript)
  }

  public init(key: (any Hashable & Sendable)? = nil, url: URL, transcript: CactusTranscript) {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    self.init(key: key ?? ConfigurationKey(loader: loader), loader, transcript: transcript)
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    configuration: CactusLanguageModel.Configuration,
    transcript: CactusTranscript
  ) {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    self.init(key: key ?? ConfigurationKey(loader: loader), loader, transcript: transcript)
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    transcript: CactusTranscript
  ) {
    let loader = DirectoryModelLoader.fromDirectory(
      slug: slug,
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    self.init(
      key: key ?? DirectoryKey(loader: loader),
      loader,
      transcript: transcript
    )
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    _ loader: any CactusAgentModelLoader,
    transcript: CactusTranscript
  ) {
    self.init(access: .loaded(key: key, loader), transcript: transcript)
  }

  public init(
    _ model: CactusLanguageModel,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(access: .direct(model), transcript: CactusTranscript())
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    url: URL,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    self.init(key: key ?? ConfigurationKey(loader: loader), loader, systemPrompt: systemPrompt)
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    configuration: CactusLanguageModel.Configuration,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    self.init(key: key ?? ConfigurationKey(loader: loader), loader, systemPrompt: systemPrompt)
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(
      key: key,
      .fromDirectory(
        slug: slug,
        contextSize: contextSize,
        corpusDirectoryURL: corpusDirectoryURL,
        directory: directory,
        downloadBehavior: downloadBehavior
      ),
      systemPrompt: systemPrompt
    )
  }

  public init(
    key: (any Hashable & Sendable)? = nil,
    _ loader: any CactusAgentModelLoader,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(key: key, loader, transcript: CactusTranscript())
  }

  private init(access: AgentModelAccess, transcript: CactusTranscript) {
    self.access = access
    self.transcript = transcript
  }

  public nonisolated(nonsending) func stream(
    request: CactusAgentRequest<Input>,
    into continuation: CactusAgentStream<Output>.Continuation
  ) async throws {
  }
}

// MARK: - Session Convenience Inits

extension CactusAgenticSession {
  public convenience init(
    _ model: sending CactusLanguageModel,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      CactusModelAgent(model, systemPrompt: systemPrompt).functions(functions),
      store: NoopModelStore()
    )
  }

  public convenience init(
    from url: URL,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      .fromModelURL(url),
      functions: functions,
      store: store,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    configuration: CactusLanguageModel.Configuration,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      .fromConfiguration(configuration),
      functions: functions,
      store: store,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      .fromDirectory(slug: slug),
      functions: functions,
      store: store,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    _ loader: sending any CactusAgentModelLoader,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      CactusModelAgent(loader, systemPrompt: systemPrompt)
        .functions(functions),
      store: store
    )
  }

  public convenience init(
    _ model: sending CactusLanguageModel,
    functions: sending [any CactusFunction] = [],
    transcript: CactusTranscript
  ) {
    self.init(
      CactusModelAgent(model, transcript: transcript).functions(functions),
      store: NoopModelStore()
    )
  }

  public convenience init(
    from url: URL,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      .fromModelURL(url),
      functions: functions,
      store: store,
      transcript: transcript
    )
  }

  public convenience init(
    configuration: CactusLanguageModel.Configuration,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      .fromConfiguration(configuration),
      functions: functions,
      store: store,
      transcript: transcript
    )
  }

  public convenience init(
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      .fromDirectory(slug: slug),
      functions: functions,
      store: store,
      transcript: transcript
    )
  }

  public convenience init(
    _ loader: sending any CactusAgentModelLoader,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      CactusModelAgent(loader, transcript: transcript)
        .transcript(transcript)
        .functions(functions),
      store: store
    )
  }
}
