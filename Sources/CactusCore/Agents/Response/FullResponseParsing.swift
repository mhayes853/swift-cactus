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
  associatedtype Partial: ConvertibleFromCactusResponse = Self
  associatedtype ConversionFailure: Error
  associatedtype PartialConversionFailure: Error

  init(cactusResponse: CactusResponse) throws(ConversionFailure)
  init(partial: Partial) throws(PartialConversionFailure)
}

extension ConvertibleFromCactusResponse where Partial == Self {
  public init(partial: Partial) {
    self = partial
  }
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
