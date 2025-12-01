public struct DirectoryModelRequest: CactusAgentModelRequest {
  public struct ID: Hashable, Sendable {
    let slug: String
    let directoryId: ObjectIdentifier
    let shouldDownloadModel: Bool
  }

  let slug: String
  let directory: CactusModelsDirectory
  let shouldDownloadModel: Bool

  public var id: ID {
    ID(
      slug: self.slug,
      directoryId: ObjectIdentifier(self.directory),
      shouldDownloadModel: self.shouldDownloadModel
    )
  }

  public func loadModel(in store: any CactusAgentModelStore) throws -> CactusLanguageModel {
    fatalError()
  }
}

extension CactusAgentModelRequest where Self == DirectoryModelRequest {
  public static func fromDirectory(
    slug: String,
    directory: CactusModelsDirectory,
    shouldDownloadModel: Bool = true
  ) -> Self {
    DirectoryModelRequest(
      slug: slug,
      directory: directory,
      shouldDownloadModel: shouldDownloadModel
    )
  }
}
