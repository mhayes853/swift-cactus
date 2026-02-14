import StreamParsingCore

// MARK: - TokenParser

extension CactusLanguageModel {
  /// Parses generated tokens into incremental partial values.
  public protocol TokenParser<Partial> {
    /// The incremental partial value produced while parsing streamed tokens.
    associatedtype Partial

    /// Parses a single generated token and returns the latest partial value if available.
    ///
    /// - Parameters:
    ///   - token: The generated token text.
    ///   - tokenId: The generated token ID.
    ///   - model: The language model instance producing tokens.
    /// - Throws: Any error encountered while parsing the token.
    /// - Returns: The latest parsed partial value, or `nil` when no parseable update is available.
    mutating func parse(token: String, tokenId: UInt32, model: CactusLanguageModel) throws
      -> Partial?
  }
}

// MARK: - StreamParsingTokenParser

extension CactusLanguageModel {
  /// A ``TokenParser`` backed by ``PartialsStream`` and any ``StreamParser`` implementation.
  ///
  /// This parser applies the following before feeding visible tokens into a stream parser:
  /// - `<think>` and `</think>` regions are ignored.
  /// - Parsing stops once a function call start token is detected.
  ///
  /// Parser errors from the underlying ``PartialsStream`` are forwarded to callers.
  public struct StreamParsingTokenParser<Parser: StreamParser>: TokenParser {
    public typealias Partial = Parser.Value

    private var accumulator = NonThinkingTokenAccumulator()
    private var stream: PartialsStream<Partial, Parser>
    private var hasDetectedFunctionCall = false

    /// Creates a token parser from a stream parser.
    ///
    /// - Parameter streamParser: The stream parser used for incremental parsing.
    public init(streamParser: Parser) {
      self.stream = PartialsStream(from: streamParser)
    }

    /// Parses a generated token into a partial value update.
    ///
    /// - Parameters:
    ///   - token: The generated token text.
    ///   - tokenId: The generated token ID.
    ///   - model: The language model instance producing tokens.
    /// - Throws: Any error thrown by the underlying parser.
    /// - Returns: The latest parsed partial value, or `nil` when no update is available.
    public mutating func parse(
      token: String,
      tokenId: UInt32,
      model: CactusLanguageModel
    ) throws -> Partial? {
      if Self.functionCallStartTokenIDs(for: model.configurationFile.modelType).contains(tokenId) {
        self.hasDetectedFunctionCall = true
      }

      if self.hasDetectedFunctionCall {
        return nil
      }

      guard let visibleToken = self.accumulator.append(token) else {
        return nil
      }

      return try self.stream.next(visibleToken.utf8)
    }

    private static func functionCallStartTokenIDs(
      for modelType: CactusLanguageModel.ModelType?
    ) -> Set<UInt32> {
      switch modelType {
      case .qwen: [151657]
      case .lfm2: [10]
      case .gemma: [48]
      default: []
      }
    }
  }
}
