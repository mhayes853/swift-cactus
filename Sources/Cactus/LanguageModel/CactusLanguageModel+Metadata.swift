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

    /// The description of this model.
    public let description: String

    /// The size of the model in megabytes.
    public let sizeMegabytes: Int

    /// Whether or not the model suppports tool calling.
    public let supportsToolCalling: Bool

    /// Whether or not the model supports vision.
    public let supportsVision: Bool

    /// Whether or not the model supports completion.
    public let supportsCompletion: Bool

    /// The number of bits used for quantization.
    public let quantizationBits: Int

    private enum CodingKeys: String, CodingKey {
      case createdAt = "created_at"
      case slug
      case description
      case name
      case downloadURL = "download_url"
      case sizeMegabytes = "size_mb"
      case supportsToolCalling = "supports_tool_calling"
      case supportsVision = "supports_vision"
      case supportsCompletion = "suppports_completion"
      case quantizationBits = "quantization"
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.createdAt = try container.decode(Date.self, forKey: .createdAt)
      self.slug = try container.decode(String.self, forKey: .slug)
      self.description = try container.decode(String?.self, forKey: .description) ?? ""
      self.name = try container.decode(String.self, forKey: .name)
      self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
      self.sizeMegabytes = try container.decode(Int.self, forKey: .sizeMegabytes)
      self.supportsToolCalling = try container.decode(Bool.self, forKey: .supportsToolCalling)
      self.supportsVision = try container.decode(Bool.self, forKey: .supportsVision)
      self.supportsCompletion = try container.decode(Bool.self, forKey: .supportsCompletion)
      self.quantizationBits = try container.decode(Int.self, forKey: .quantizationBits)
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
