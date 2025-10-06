import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class CactusSupabaseClient: Sendable {
  static let shared = CactusSupabaseClient()

  private let cactusSupabaseURL = "https://vlqqczxwyaodtcdmdmlw.supabase.co"
  private let cactusSupabaseKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZscXFjenh3eWFvZHRjZG1kbWx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1MTg2MzIsImV4cCI6MjA2NzA5NDYzMn0.nBzqGuK9j6RZ6mOPWU2boAC_5H9XDs-fPpo5P3WZYbI"

  private let session = URLSession.shared

  private let supabaseJSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  func availableModels() async throws -> [CactusLanguageModel.Metadata] {
    var components = URLComponents(string: "\(cactusSupabaseURL)/rest/v1/models")!
    components.queryItems = [URLQueryItem(name: "select", value: "*")]

    var request = URLRequest(url: components.url!)
    request.addValue(cactusSupabaseKey, forHTTPHeaderField: "apiKey")
    request.addValue("Bearer \(cactusSupabaseKey)", forHTTPHeaderField: "Authorization")
    request.addValue("cactus", forHTTPHeaderField: "Accept-Profile")

    let (data, _) = try await URLSession.shared.data(for: request)
    return try self.supabaseJSONDecoder.decode([CactusLanguageModel.Metadata].self, from: data)
  }

  func modelDownloadURL(for slug: String) -> URL {
    URL(string: "\(cactusSupabaseURL)/storage/v1/object/public/cactus-models/\(slug).zip")!
  }
}
