// MARK: - CactusStreamedToken

public struct CactusStreamedToken: Hashable, Sendable {
  public let generationStreamId: CactusGenerationID
  public let token: String

  public init(generationStreamId: CactusGenerationID, token: String) {
    self.generationStreamId = generationStreamId
    self.token = token
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
    private var output = ""

    public init() {}

    public mutating func next(
      from token: CactusStreamedToken,
      in environment: CactusEnvironmentValues
    ) throws -> String {
      self.output += token.token
      return self.output
    }
  }
}
