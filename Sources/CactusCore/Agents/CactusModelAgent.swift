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

  public static func fromModelURL(
    key: (any Hashable & Sendable)? = nil,
    _ url: URL,
    transcript: CactusTranscript
  ) -> Self {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    return Self(key: key ?? ConfigurationKey(loader: loader), loader, transcript: transcript)
  }

  public static func fromConfiguration(
    key: (any Hashable & Sendable)? = nil,
    _ configuration: CactusLanguageModel.Configuration,
    transcript: CactusTranscript
  ) -> Self {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    return Self(key: key ?? ConfigurationKey(loader: loader), loader, transcript: transcript)
  }

  public static func fromDirectory(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    transcript: CactusTranscript
  ) -> Self {
    let loader = DirectoryModelLoader.fromDirectory(
      slug: slug,
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    return Self(
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

  public static func fromModelURL(
    key: (any Hashable & Sendable)? = nil,
    _ url: URL,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) -> Self {
    let loader = ConfigurationModelLoader.fromModelURL(url)
    return Self(key: key ?? ConfigurationKey(loader: loader), loader, systemPrompt: systemPrompt)
  }

  public static func fromConfiguration(
    key: (any Hashable & Sendable)? = nil,
    _ configuration: CactusLanguageModel.Configuration,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) -> Self {
    let loader = ConfigurationModelLoader.fromConfiguration(configuration)
    return Self(key: key ?? ConfigurationKey(loader: loader), loader, systemPrompt: systemPrompt)
  }

  public static func fromDirectory(
    key: (any Hashable & Sendable)? = nil,
    slug: String,
    contextSize: Int = 2048,
    corpusDirectoryURL: URL? = nil,
    directory: CactusModelsDirectory? = nil,
    downloadBehavior: CactusAgentModelDownloadBehavior? = nil,
    @CactusPromptBuilder systemPrompt: () -> some CactusPromptRepresentable
  ) -> Self {
    let loader = DirectoryModelLoader.fromDirectory(
      slug: slug,
      contextSize: contextSize,
      corpusDirectoryURL: corpusDirectoryURL,
      directory: directory,
      downloadBehavior: downloadBehavior
    )
    return Self(
      key: key ?? DirectoryKey(loader: loader),
      loader,
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
