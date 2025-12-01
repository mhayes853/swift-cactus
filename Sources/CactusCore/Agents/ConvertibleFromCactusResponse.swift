// MARK: - ConvertibleFromCactusResponse

public protocol ConvertibleFromCactusResponse {
  associatedtype Partial: ConvertibleFromCactusResponse = Self
  associatedtype ConversionFailure: Error

  init(cactusResponse: String) throws(ConversionFailure)
}

// MARK: - Base Conformances

extension String: ConvertibleFromCactusResponse {
  public init(cactusResponse: String) {
    self = cactusResponse
  }
}
