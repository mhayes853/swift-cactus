// MARK: - CactusStreamedToken

public struct CactusStreamedToken: Hashable, Sendable {
  public let generationStreamId: CactusMessageID
  public let stringValue: String

  public init(generationStreamId: CactusMessageID, stringValue: String) {
    self.generationStreamId = generationStreamId
    self.stringValue = stringValue
  }
}

// MARK: - ConvertibleFromCactusTokenStream

public protocol ConvertibleFromCactusTokenStream<TokenStreamParser> {
  associatedtype TokenStreamParser: CactusTokenStreamParser<Self>

  static func tokenParser(in environment: CactusEnvironmentValues) -> TokenStreamParser
}

// MARK: - CactusTokenParser

public protocol CactusTokenStreamParser<Value> {
  associatedtype Value

  mutating func next(
    from token: CactusStreamedToken,
    in environment: CactusEnvironmentValues
  ) throws -> Value
}

// MARK: - Basic Conformances

extension String: ConvertibleFromCactusTokenStream {
  @inlinable
  @inline(__always)
  public static func tokenParser(in environment: CactusEnvironmentValues) -> TokenStreamParser {
    TokenStreamParser()
  }

  public struct TokenStreamParser: CactusTokenStreamParser {
    @usableFromInline
    var output = ""

    @usableFromInline
    init() {}

    @inlinable
    @inline(__always)
    public mutating func next(
      from token: CactusStreamedToken,
      in environment: CactusEnvironmentValues
    ) throws -> String {
      self.output += token.stringValue
      return self.output
    }
  }
}
