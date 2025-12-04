extension JSONValue: ConvertibleFromCactusTokenStream {
  public static func tokenParser(in environment: CactusEnvironmentValues) -> TokenParser {
    TokenParser()
  }

  public struct TokenParser: CactusTokenParser {
    public mutating func next(
      from token: CactusStreamedToken,
      in environment: CactusEnvironmentValues
    ) throws -> JSONValue {
      .null
    }
  }
}
