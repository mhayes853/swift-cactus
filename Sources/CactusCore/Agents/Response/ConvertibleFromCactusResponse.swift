// MARK: - ConvertibleFromCactusResponse

public protocol ConvertibleFromCactusResponse {
  associatedtype Partial: ConvertibleFromCactusResponse = Self
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
