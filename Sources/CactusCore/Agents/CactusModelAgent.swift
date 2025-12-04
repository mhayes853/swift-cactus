import Foundation

// MARK: - CactusModelAgent

public struct CactusModelAgent<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse,
  Loader: CactusAgentModelLoader
>: CactusAgent {
  private let key: AnyHashable?
  private let loader: Loader
  private let transcript: CactusTranscript

  public init(key: AnyHashable? = nil, _ model: CactusLanguageModel, transcript: CactusTranscript)
  where Loader == ConstantModelLoader {
    self.init(key: key, .constant(model), transcript: transcript)
  }

  public init(key: AnyHashable? = nil, url: URL, transcript: CactusTranscript)
  where Loader == ConfigurationModelLoader {
    self.init(key: key, .fromModelURL(url), transcript: transcript)
  }

  public init(
    key: AnyHashable? = nil,
    configuration: CactusLanguageModel.Configuration,
    transcript: CactusTranscript
  )
  where Loader == ConfigurationModelLoader {
    self.init(key: key, .fromConfiguration(configuration), transcript: transcript)
  }

  public init(
    key: AnyHashable? = nil,
    modelSlug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    transcript: CactusTranscript
  )
  where Loader == DirectoryModelLoader {
    self.init(
      key: key,
      .fromDirectory(
        slug: modelSlug,
        contextSize: contextSize,
        corpusDirectoryURL: corpusDirectoryURL,
        directory: directory,
        downloadBehavior: downloadBehavior
      ),
      transcript: transcript
    )
  }

  public init(key: AnyHashable? = nil, _ loader: Loader, transcript: CactusTranscript) {
    self.key = key
    self.loader = loader
    self.transcript = transcript
  }

  public init(
    key: AnyHashable? = nil,
    _ model: CactusLanguageModel,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) where Loader == ConstantModelLoader {
    self.init(key: key, .constant(model), systemPrompt: systemPrompt)
  }

  public init(
    key: AnyHashable? = nil,
    url: URL,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  )
  where Loader == ConfigurationModelLoader {
    self.init(key: key, .fromModelURL(url), systemPrompt: systemPrompt)
  }

  public init(
    key: AnyHashable? = nil,
    configuration: CactusLanguageModel.Configuration,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  )
  where Loader == ConfigurationModelLoader {
    self.init(key: key, .fromConfiguration(configuration), systemPrompt: systemPrompt)
  }

  public init(
    key: AnyHashable? = nil,
    modelSlug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) where Loader == DirectoryModelLoader {
    self.init(
      key: key,
      .fromDirectory(
        slug: modelSlug,
        contextSize: contextSize,
        corpusDirectoryURL: corpusDirectoryURL,
        directory: directory,
        downloadBehavior: downloadBehavior
      ),
      systemPrompt: systemPrompt
    )
  }

  public init(
    key: AnyHashable? = nil,
    _ loader: Loader,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) {
    self.init(key: key, loader, transcript: CactusTranscript())
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
      .constant(model),
      functions: functions,
      store: store,
      systemPrompt: systemPrompt
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
    modelSlug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    @CactusPromptBuilder systemPrompt: sending () -> some CactusPromptRepresentable
  ) {
    self.init(
      .fromDirectory(slug: modelSlug),
      functions: functions,
      store: store,
      systemPrompt: systemPrompt
    )
  }

  public convenience init(
    _ loader: sending some CactusAgentModelLoader,
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
    store: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      .constant(model),
      functions: functions,
      store: store,
      transcript: transcript
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
    modelSlug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    functions: sending [any CactusFunction] = [],
    store: sending any CactusAgentModelStore = SessionModelStore(),
    transcript: CactusTranscript
  ) {
    self.init(
      .fromDirectory(slug: modelSlug),
      functions: functions,
      store: store,
      transcript: transcript
    )
  }

  public convenience init(
    _ loader: sending some CactusAgentModelLoader,
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
