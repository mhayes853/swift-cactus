internal import CXXCactus
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - CactusLanguageModel

public final class CactusLanguageModel {
  public let configuration: Configuration
  private let model: cactus_model_t

  public convenience init(from url: URL, contextSize: Int = 2048) throws {
    try self.init(configuration: Configuration(modelURL: url, contextSize: contextSize))
  }

  public init(configuration: Configuration) throws {
    self.configuration = configuration
    let model = cactus_init(configuration.modelURL.nativePath, configuration.contextSize)
    guard let model else { throw ModelCreationError(configuration: configuration) }
    self.model = model
  }

  deinit { cactus_destroy(self.model) }
}

// MARK: - Configuration

extension CactusLanguageModel {
  public struct Configuration: Hashable, Sendable {
    public var modelURL: URL
    public var contextSize: Int

    public init(modelURL: URL, contextSize: Int = 2048) {
      self.modelURL = modelURL
      self.contextSize = contextSize
    }
  }
}

// MARK: - Tool

extension CactusLanguageModel {
  public protocol Tool {

  }
}

// MARK: - Errors

extension CactusLanguageModel {
  public struct ModelCreationError: Error, Hashable {
    public let message: String

    init(configuration: Configuration) {
      if let message = cactus_get_last_error() {
        self.message = String(cString: message)
      } else {
        self.message = "Failed to create model with configuration: \(configuration)"
      }
    }
  }
}

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
  private static let supabaseJSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public static func availableModels() async throws -> [Metadata] {
    var components = URLComponents(string: "\(cactusSupabaseURL)/rest/v1/models")!
    components.queryItems = [URLQueryItem(name: "select", value: "*")]

    var request = URLRequest(url: components.url!)
    request.addValue(cactusSupabaseKey, forHTTPHeaderField: "apiKey")
    request.addValue("Bearer \(cactusSupabaseKey)", forHTTPHeaderField: "Authorization")
    request.addValue("cactus", forHTTPHeaderField: "Accept-Profile")

    let (data, _) = try await URLSession.shared.data(for: request)
    return try Self.supabaseJSONDecoder.decode([Metadata].self, from: data)
  }
}
