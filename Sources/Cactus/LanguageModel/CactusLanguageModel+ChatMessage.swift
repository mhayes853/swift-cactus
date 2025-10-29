// MARK: - ChatMessage

extension CactusLanguageModel {
  /// A chat message.
  public struct ChatMessage: Hashable, Sendable, Encodable {
    /// The ``Role`` of the message.
    public var role: Role

    /// The message content.
    public var content: String

    /// Creates a chat message.
    ///
    /// - Parameters:
    ///   - role: The ``Role`` of the message.
    ///   - content: The message content.
    public init(role: Role, content: String) {
      self.role = role
      self.content = content
    }
  }
}

// MARK: - Role

extension CactusLanguageModel.ChatMessage {
  /// A role for a chat message.
  public struct Role: Hashable, Sendable, Codable, RawRepresentable {
    /// A system message role.
    ///
    /// Use this role when providing instructions to the model
    /// (eg. `"You are a helpful assistant..."`).
    public static let system = Role(rawValue: "system")

    /// A user message role.
    ///
    /// Use this role when providing user created input to the model.
    public static let user = Role(rawValue: "user")

    /// An assitant role.
    ///
    /// Use this role when providing the model with one of its previous responses.
    public static let assistant = Role(rawValue: "assistant")

    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  /// Creates a system message.
  ///
  /// Use this initializer when providing instructions to the model
  /// (eg. `"You are a helpful assistant..."`).
  ///
  /// - Parameter content: The message content.
  /// - Returns: A ``CactusLanguageModel/ChatMessage``.
  public static func system(_ content: String) -> Self {
    Self(role: .system, content: content)
  }

  /// Creates a user message.
  ///
  /// Use this initializer when providing user created input to the model.
  ///
  /// - Parameter content: The message content.
  /// - Returns: A ``CactusLanguageModel/ChatMessage``.
  public static func user(_ content: String) -> Self {
    Self(role: .user, content: content)
  }

  /// Creates an assistant message.
  ///
  /// Use this initializer when providing the model with one of its previous responses.
  ///
  /// - Parameter content: The message content.
  /// - Returns: A ``CactusLanguageModel/ChatMessage``.
  public static func assistant(_ content: String) -> Self {
    Self(role: .assistant, content: content)
  }
}

extension CactusLanguageModel.ChatMessage.Role: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(rawValue: value)
  }
}
