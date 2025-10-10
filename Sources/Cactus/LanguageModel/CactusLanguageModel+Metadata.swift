import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - Metadata

extension CactusLanguageModel {
  /// Language model metadata.
  public struct Metadata: Hashable, Sendable, Codable {
    /// The date of when this model became available.
    public let createdAt: Date
    
    /// The slug for this model.
    public let slug: String
    
    /// A human readable name of this model.
    public let name: String
    
    /// A `URL` to download the model.
    public let downloadURL: URL
    
    /// The size of the model in megabytes.
    public let sizeMegabytes: Int
    
    /// Whether or not the model suppports tool calling.
    public let supportsToolCalling: Bool
    
    /// Whether or not the model supports vision.
    public let supportsVision: Bool

    private enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case slug
      case name
      case downloadURL = "download_url"
      case sizeMegabytes = "size_mb"
      case supportsToolCalling = "supports_tool_calling"
      case supportsVision = "supports_vision"
    }
  }
}

// MARK: - Available Models

extension CactusLanguageModel {
  /// Fetches an array of ``Metadata`` of models supported by cactus.
  ///
  /// - Returns: A ``Metadata`` array.
  public static func availableModels() async throws -> [Metadata] {
    try await CactusSupabaseClient.shared.availableModels()
  }
}
