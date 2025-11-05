// MARK: - ChatMessage

extension CactusLanguageModel {
  /// A chat message.
  public struct ChatMessage: Hashable, Sendable, Encodable {
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

    /// The ``MessageRole`` of the message.
    public var role: MessageRole

    /// The message content.
    public var content: String

    /// Creates a chat message.
    ///
    /// - Parameters:
    ///   - role: The ``MessageRole`` of the message.
    ///   - content: The message content.
    public init(role: MessageRole, content: String) {
      self.role = role
      self.content = content
    }
  }
}

// MARK: - Role

extension CactusLanguageModel {
  /// A role for a chat message.
  public struct MessageRole: Hashable, Sendable, Codable, RawRepresentable {
    /// A system message role.
    ///
    /// Use this role when providing instructions to the model
    /// (eg. `"You are a helpful assistant..."`).
    public static let system = MessageRole(rawValue: "system")

    /// A user message role.
    ///
    /// Use this role when providing user created input to the model.
    public static let user = MessageRole(rawValue: "user")

    /// An assitant role.
    ///
    /// Use this role when providing the model with one of its previous responses.
    public static let assistant = MessageRole(rawValue: "assistant")

    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

extension CactusLanguageModel.MessageRole: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(rawValue: value)
  }
}
