extension JSONValue: ConvertibleFromCactusTokenStream {
  public struct TokenParser: CactusTokenParser {
    public init() {}

    public mutating func next(
      from token: CactusStreamedToken,
      in environment: CactusEnvironmentValues
    ) throws -> JSONValue {
      .null
    }
  }
}
