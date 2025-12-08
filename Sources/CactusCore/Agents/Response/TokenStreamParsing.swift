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

public protocol ConvertibleFromCactusTokenStream<TokenParser> {
  associatedtype TokenParser: CactusTokenParser<Self>

  static func tokenParser(in environment: CactusEnvironmentValues) -> TokenParser
}

// MARK: - CactusTokenParser

public protocol CactusTokenParser<Value> {
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
  public static func tokenParser(in environment: CactusEnvironmentValues) -> TokenParser {
    TokenParser()
  }

  public struct TokenParser: CactusTokenParser {
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
