import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - CactusLanguageModel

public final class CactusLanguageModel {

}

// MARK: - Available Models

extension CactusLanguageModel {
  private static let jsonDecoder = {
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
    return try Self.jsonDecoder.decode([Metadata].self, from: data)
  }
}
