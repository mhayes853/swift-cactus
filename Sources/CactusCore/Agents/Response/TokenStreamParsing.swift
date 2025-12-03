// MARK: - CactusStreamedToken

public struct CactusStreamedToken: Hashable, Sendable {
  public let generationStreamId: CactusGenerationID
  public let stringValue: String

  public init(generationStreamId: CactusGenerationID, stringValue: String) {
    self.generationStreamId = generationStreamId
    self.stringValue = stringValue
  }
}

// MARK: - ConvertibleFromCactusTokenStream

public protocol ConvertibleFromCactusTokenStream<TokenParser> {
  associatedtype TokenParser: CactusTokenParser<Self>
}

// MARK: - CactusTokenParser

public protocol CactusTokenParser<Value> {
  associatedtype Value

  init()

  mutating func next(
    from token: CactusStreamedToken,
    in environment: CactusEnvironmentValues
  ) throws -> Value
}

// MARK: - Basic Conformances

extension String: ConvertibleFromCactusTokenStream {
  public struct TokenParser: CactusTokenParser {
    @usableFromInline
    var output = ""

    @inlinable
    public init() {}

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
