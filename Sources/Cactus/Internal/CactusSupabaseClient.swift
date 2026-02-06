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
}

// MARK: - Available Models

extension CactusSupabaseClient {
  func availableModels() async throws -> [CactusLanguageModel.Metadata] {
    var components = URLComponents(string: self.baseURL(for: "/rest/v1/models").absoluteString)!
    components.queryItems = [
      URLQueryItem(name: "select", value: "*"),
      URLQueryItem(name: "is_live", value: "eq.true")
    ]

    let (data, _) = try await self.session.data(for: self.baseRequest(for: components.url!))
    return try self.supabaseJSONDecoder.decode([CactusLanguageModel.Metadata].self, from: data)
  }

  func availableAudioModels() async throws -> [CactusLanguageModel.AudioMetadata] {
    var components = URLComponents(string: self.baseURL(for: "/rest/v1/whisper").absoluteString)!
    components.queryItems = [URLQueryItem(name: "select", value: "*")]

    let (data, _) = try await self.session.data(for: self.baseRequest(for: components.url!))
    return try self.supabaseJSONDecoder.decode([CactusLanguageModel.AudioMetadata].self, from: data)
  }
}

// MARK: - Model Download URL

extension CactusSupabaseClient {
  func modelDownloadURL(for request: CactusLanguageModel.PlatformDownloadRequest) -> URL {
    let base =
      "\(self.cactusSupabaseURL)/storage/v1/object/public/cactus-models/\(request.version.rawValue)/\(request.quantization.rawValue)"
    if let pro = request.pro {
      return URL(string: "\(base)/pro/\(pro.rawValue)/\(request.slug).zip")!
    }
    return URL(string: "\(base)/\(request.slug).zip")!
  }

  func audioModelDownloadURL(for slug: String) -> URL {
    URL(
      string: "\(self.cactusSupabaseURL)/storage/v1/object/public/voice-models/\(slug).zip"
    )!
  }
}

// MARK: - Helper

extension CactusSupabaseClient {
  private func baseURL(for endpoint: String) -> URL {
    URL(string: "\(self.cactusSupabaseURL)\(endpoint)")!
  }

  private func baseRequest(for url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.addValue(self.cactusSupabaseKey, forHTTPHeaderField: "apiKey")
    request.addValue("Bearer \(self.cactusSupabaseKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("cactus", forHTTPHeaderField: "Content-Profile")
    request.addValue("cactus", forHTTPHeaderField: "Accept-Profile")
    return request
  }
}
