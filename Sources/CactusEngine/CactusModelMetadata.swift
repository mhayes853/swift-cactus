import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - CactusModelMetadata

public struct CactusModelMetadata: Hashable, Sendable, Codable {
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

// MARK: - Available

extension CactusModelMetadata {
  private static let jsonDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public static func availableModels() async throws -> [Self] {
    var components = URLComponents(string: "\(cactusSupabaseURL)/rest/v1/models")!
    components.queryItems = [URLQueryItem(name: "select", value: "*")]

    var request = URLRequest(url: components.url!)
    request.addValue(cactusSupabaseKey, forHTTPHeaderField: "apiKey")
    request.addValue("Bearer \(cactusSupabaseKey)", forHTTPHeaderField: "Authorization")
    request.addValue("cactus", forHTTPHeaderField: "Accept-Profile")

    let (data, _) = try await URLSession.shared.data(for: request)
    return try Self.jsonDecoder.decode([CactusModelMetadata].self, from: data)
  }
}
