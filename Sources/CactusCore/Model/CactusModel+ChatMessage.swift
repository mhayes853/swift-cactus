import Foundation

// MARK: - Message

extension CactusModel {
  /// A message.
  public struct Message: Hashable, Sendable, Codable {
    /// Creates a system message.
    ///
    /// Use this initializer when providing instructions to the model
    /// (eg. `"You are a helpful assistant..."`).
    ///
    /// - Parameter content: The message content.
    /// - Returns: A ``CactusModel/Message``.
    public static func system(_ content: String) -> Self {
      Self(role: .system, content: content)
    }

    /// Creates a user message.
    ///
    /// Use this initializer when providing user created input to the model.
    ///
    /// - Parameters:
    ///   - content: The message content.
    ///   - images: An array of `URL`s to locally stored images.
    /// - Returns: A ``CactusModel/Message``.
    public static func user(_ content: String, images: [URL]? = nil) -> Self {
      Self(role: .user, content: content, images: images)
    }

    /// Creates an assistant message.
    ///
    /// Use this initializer when providing the model with one of its previous responses.
    ///
    /// - Parameter content: The message content.
    /// - Returns: A ``CactusModel/Message``.
    public static func assistant(_ content: String) -> Self {
      Self(role: .assistant, content: content)
    }

    /// The ``Role`` of the message.
    public var role: Role

    /// The message content.
    public var content: String

    /// An array of `URL`s to locally stored images.
    public var images: [URL]?

    /// Creates a message.
    ///
    /// - Parameters:
    ///   - role: The ``Role`` of the message.
    ///   - content: The message content.
    ///   - images: An array of `URL`s to locally stored images.
    public init(role: Role, content: String, images: [URL]? = nil) {
      self.role = role
      self.content = content
      self.images = images
    }
  }
}

// MARK: - Role

extension CactusModel.Message {
  /// A role for a message.
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

    /// A tool output role.
    ///
    /// This role represents tool/function output messages.
    public static let tool = Role(rawValue: "tool")

    /// A function output role.
    ///
    /// This role aliases ``tool``.
    public static let function = Role.tool

    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

extension CactusModel.Message.Role: ExpressibleByStringLiteral {
  public init(stringLiteral value: StringLiteralType) {
    self.init(rawValue: value)
  }
}
