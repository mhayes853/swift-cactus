import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - Metadata

extension CactusLanguageModel {
  public struct Metadata: Hashable, Sendable, Codable {
    public let createdAt: Date
    public let slug: String
    public let name: String
    public let downloadURL: URL
    public let sizeMegabytes: Int
    public let supportsToolCalling: Bool
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
  public static func availableModels() async throws -> [Metadata] {
    try await CactusSupabaseClient.shared.availableModels()
  }
}
