private import CXXCactus
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

// MARK: - CactusLanguageModel

public final class CactusLanguageModel {
  public let configuration: Configuration
  private let model: cactus_model_t

  public convenience init(from url: URL, contextSize: Int = 2048) throws {
    try self.init(configuration: Configuration(modelURL: url, contextSize: contextSize))
  }

  public init(configuration: Configuration) throws {
    self.configuration = configuration
    let model = cactus_init(configuration.modelURL.nativePath, configuration.contextSize)
    guard let model else { throw ModelCreationError(configuration: configuration) }
    self.model = model
  }

  deinit { cactus_destroy(self.model) }
}

// MARK: - Configuration

extension CactusLanguageModel {
  public struct Configuration: Hashable, Sendable {
    public var modelURL: URL
    public var contextSize: Int

    public init(modelURL: URL, contextSize: Int = 2048) {
      self.modelURL = modelURL
      self.contextSize = contextSize
    }
  }
}

// MARK: - Creation Error

extension CactusLanguageModel {
  public struct ModelCreationError: Error, Hashable {
    public let message: String

    init(configuration: Configuration) {
      if let message = cactus_get_last_error() {
        self.message = String(cString: message)
      } else {
        self.message = "Failed to create model with configuration: \(configuration)"
      }
    }
  }
}

// MARK: - Embeddings

extension CactusLanguageModel {
  public enum EmbeddingsError: Error, Hashable {
    case bufferTooSmall
    case unknown(message: String?)
  }

  public func embeddings(for text: String, maxBufferSize: Int = 2048) throws -> [Float] {
    let rawBuffer = UnsafeMutablePointer<Float>.allocate(capacity: maxBufferSize)
    defer { rawBuffer.deallocate() }
    var buffer = MutableSpan(_unsafeStart: rawBuffer, count: maxBufferSize)
    let dimensions = try self.embeddings(for: text, buffer: &buffer)
    return (0..<dimensions).map { buffer[$0] }
  }

  @discardableResult
  public func embeddings(for text: String, buffer: inout MutableSpan<Float>) throws -> Int {
    let size = buffer.count
    guard size > 0 else { throw EmbeddingsError.bufferTooSmall }
    return try buffer.withUnsafeMutableBufferPointer { ptr in
      var dimensions = 0
      let rawBufferSize = size * MemoryLayout<Float>.stride
      switch cactus_embed(self.model, text, ptr.baseAddress, rawBufferSize, &dimensions) {
      case -1:
        throw EmbeddingsError.unknown(message: cactus_get_last_error().map { String(cString: $0) })
      case -2:
        throw EmbeddingsError.bufferTooSmall
      default:
        return dimensions
      }
    }
  }
}

// MARK: - Chat Completion

extension CactusLanguageModel {
  public struct ChatCompletion: Hashable, Sendable {
    public let response: String
    public let tokensPerSecond: Double
    public let prefillTokens: Int
    public let decodeTokens: Int
    public let totalTokens: Int
    public private(set) var toolCalls: [ToolCall]
    private let timeToFirstTokenMs: Double
    private let totalTimeMs: Double

    public var timeIntervalToFirstToken: TimeInterval {
      self.timeToFirstTokenMs / 1000
    }

    public var totalTimeInterval: TimeInterval {
      self.totalTimeMs / 1000
    }
  }

  public enum ChatCompletionError: Error, Hashable {
    case bufferSizeTooSmall
    case generation(message: String?)
  }

  public func chatCompletion(
    messages: [ChatMessage],
    options: ChatCompletion.Options = ChatCompletion.Options(),
    maxBufferSize: Int = 2048,
    tools: [ToolDefinition] = [],
    onToken: @escaping (String) -> Void = { _ in }
  ) throws -> ChatCompletion {
    guard maxBufferSize > 0 else { throw ChatCompletionError.bufferSizeTooSmall }

    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: maxBufferSize)
    defer { buffer.deallocate() }

    let tools = tools.map { _ToolDefinition(function: $0) }
    let toolsJSON =
      tools.isEmpty ? nil : String(decoding: try JSONEncoder().encode(tools), as: UTF8.self)

    let box = Unmanaged.passRetained(TokenCallbackBox(onToken))
    defer { box.release() }
    let result = cactus_complete(
      self.model,
      String(decoding: try JSONEncoder().encode(messages), as: UTF8.self),
      buffer,
      maxBufferSize * MemoryLayout<CChar>.stride,
      String(decoding: try JSONEncoder().encode(options), as: UTF8.self),
      toolsJSON,
      { token, _, ptr in
        guard let ptr, let token else { return }
        let box = Unmanaged<TokenCallbackBox>.fromOpaque(ptr).takeUnretainedValue()
        box.callback(String(cString: token))
      },
      box.toOpaque()
    )

    var responseData = Data()
    for i in 0..<strnlen(buffer, maxBufferSize) {
      responseData.append(UInt8(bitPattern: buffer[i]))
    }

    guard result != -1 else {
      let response = try? JSONDecoder().decode(CompletionErrorResponse.self, from: responseData)
      if response?.error == "Response buffer too small" {
        throw ChatCompletionError.bufferSizeTooSmall
      }
      throw ChatCompletionError.generation(message: response?.error)
    }
    return try JSONDecoder().decode(ChatCompletion.self, from: responseData)
  }

  private struct _ToolDefinition: Codable {
    var function: ToolDefinition
  }

  private final class TokenCallbackBox {
    let callback: (String) -> Void

    init(_ callback: @escaping (String) -> Void) {
      self.callback = callback
    }
  }

  private struct CompletionErrorResponse: Decodable {
    let error: String
  }
}

extension CactusLanguageModel.ChatCompletion {
  public struct Options: Hashable, Sendable, Codable {
    public var maxTokens: Int
    public var temperature: Float
    public var topP: Float
    public var topK: Float
    public var stopSequences: [String]

    public init(
      maxTokens: Int = 200,
      temperature: Float = 0.1,
      topP: Float = 0.95,
      topK: Float = 40,
      stopSequences: [String] = []
    ) {
      self.maxTokens = maxTokens
      self.temperature = temperature
      self.topP = topP
      self.topK = topK
      self.stopSequences = stopSequences
    }

    private enum CodingKeys: String, CodingKey {
      case maxTokens = "max_tokens"
      case temperature
      case topP = "top_p"
      case topK = "top_k"
      case stopSequences = "stop_sequences"
    }
  }
}

extension CactusLanguageModel.ChatCompletion: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.response = try container.decode(String.self, forKey: .response)
    self.tokensPerSecond = try container.decode(Double.self, forKey: .tokensPerSecond)
    self.prefillTokens = try container.decode(Int.self, forKey: .prefillTokens)
    self.decodeTokens = try container.decode(Int.self, forKey: .decodeTokens)
    self.totalTokens = try container.decode(Int.self, forKey: .totalTokens)
    self.toolCalls =
      try container.decodeIfPresent([CactusLanguageModel.ToolCall].self, forKey: .toolCalls) ?? []
    self.timeToFirstTokenMs = try container.decode(Double.self, forKey: .timeToFirstTokenMs)
    self.totalTimeMs = try container.decode(Double.self, forKey: .totalTimeMs)
  }
}

extension CactusLanguageModel.ChatCompletion: Encodable {
  private enum CodingKeys: String, CodingKey {
    case response
    case tokensPerSecond = "tokens_per_second"
    case prefillTokens = "prefill_tokens"
    case decodeTokens = "decode_tokens"
    case totalTokens = "total_tokens"
    case toolCalls = "tool_calls"
    case timeToFirstTokenMs = "time_to_first_token_ms"
    case totalTimeMs = "total_time_ms"
  }
}

// MARK: - Tools

extension CactusLanguageModel {
  public struct ToolDefinition: Hashable, Sendable, Codable {
    public var name: String
    public var description: String
    public var parameters: Parameters

    public init(name: String, description: String, parameters: Parameters) {
      self.name = name
      self.description = description
      self.parameters = parameters
    }
  }
}

extension CactusLanguageModel.ToolDefinition {
  public struct Parameters: Hashable, Sendable, Codable {
    public private(set) var type = CactusLanguageModel.SchemaType.object
    public var required: [String]
    public var properties: [String: Parameter]

    public init(properties: [String: Parameter], required: [String]) {
      self.required = required
      self.properties = properties
    }
  }
}

extension CactusLanguageModel.ToolDefinition {
  public struct Parameter: Hashable, Sendable, Codable {
    public var type: CactusLanguageModel.SchemaType
    public var description: String

    public init(type: CactusLanguageModel.SchemaType, description: String) {
      self.type = type
      self.description = description
    }
  }
}

extension CactusLanguageModel {
  public struct ToolCall: Hashable, Sendable, Codable {
    public var name: String
    public var arguments: [String: SchemaValue]

    public init(name: String, arguments: [String: SchemaValue]) {
      self.name = name
      self.arguments = arguments
    }
  }
}

// MARK: - SchemaType

extension CactusLanguageModel {
  public enum SchemaType: Hashable, Sendable, Codable {
    case integer
    case string
    case boolean
    case array
    case object
    case number
    case null
    case types([Self])
  }
}

// MARK: - SchemaValue

extension CactusLanguageModel {
  public enum SchemaValue: Hashable, Sendable {
    case string(String)
    case boolean(Bool)
    case array([SchemaValue])
    case object([String: SchemaValue])
    case number(Double)
    case null
  }
}

extension CactusLanguageModel.SchemaValue: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let array): try container.encode(array)
    case .boolean(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .number(let number): try container.encode(number)
    case .object(let object): try container.encode(object)
    case .string(let string): try container.encode(string)
    }
  }
}

extension CactusLanguageModel.SchemaValue: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let array = try? container.decode([Self].self) {
      self = .array(array)
    } else if let object = try? container.decode([String: Self].self) {
      self = .object(object)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value.")
    }
  }
}

// MARK: - ChatMessage

extension CactusLanguageModel {
  public struct ChatMessage: Hashable, Sendable, Encodable {
    public var role: Role
    public var content: String

    public init(role: Role, content: String) {
      self.role = role
      self.content = content
    }
  }
}

extension CactusLanguageModel.ChatMessage {
  public struct Role: Hashable, Sendable, Codable, RawRepresentable {
    public static let system = Role(rawValue: "system")
    public static let user = Role(rawValue: "user")
    public static let assistant = Role(rawValue: "assistant")

    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public static func system(_ content: String) -> Self {
    Self(role: .system, content: content)
  }

  public static func user(_ content: String) -> Self {
    Self(role: .user, content: content)
  }

  public static func assistant(_ content: String) -> Self {
    Self(role: .assistant, content: content)
  }
}

extension CactusLanguageModel.ChatMessage.Role: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(rawValue: value)
  }
}

// MARK: - Stop

extension CactusLanguageModel {
  public func stop() {
    cactus_stop(self.model)
  }
}

// MARK: - Reset

extension CactusLanguageModel {
  public func reset() {
    cactus_reset(self.model)
  }
}
