import Foundation

struct Secrets: Sendable, Codable {
  let proKey: String

  static let current = {
    try? Bundle.module.url(forResource: "secrets", withExtension: "json")
      .map { try JSONDecoder().decode(Secrets.self, from: Data(contentsOf: $0)) }
  }()
}
