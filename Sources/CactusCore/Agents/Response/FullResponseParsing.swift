// MARK: - CactusResponse

public struct CactusResponse: Hashable, Sendable, Identifiable {
  public var id: CactusGenerationID
  public var content: String

  public init(id: CactusGenerationID, content: String) {
    self.id = id
    self.content = content
  }
}

// MARK: - ConvertibleFromCactusResponse

public protocol ConvertibleFromCactusResponse {
  associatedtype Partial = Self
  associatedtype ConversionFailure: Error

  init(cactusResponse: CactusResponse) throws(ConversionFailure)
}

// MARK: - Base Conformances

extension String: ConvertibleFromCactusResponse {
  public init(cactusResponse: CactusResponse) {
    self = cactusResponse.content
  }
}

extension CactusResponse: ConvertibleFromCactusResponse {
  public init(cactusResponse: CactusResponse) {
    self = cactusResponse
  }
}
