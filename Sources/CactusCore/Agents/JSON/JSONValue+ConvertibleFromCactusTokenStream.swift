extension JSONValue: ConvertibleFromCactusTokenStream {
  public static func tokenParser(in environment: CactusEnvironmentValues) -> TokenStreamParser {
    TokenStreamParser()
  }

  public struct TokenStreamParser: CactusTokenStreamParser {
    public mutating func next(
      from token: CactusStreamedToken,
      in environment: CactusEnvironmentValues
    ) throws -> JSONValue {
      .null
    }
  }
}
