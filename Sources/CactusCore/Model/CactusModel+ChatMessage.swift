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
    ///   - audio: An array of `URL`s to locally stored audio files.
    /// - Returns: A ``CactusModel/Message``.
    public static func user(_ content: String, images: [URL]? = nil, audio: [URL]? = nil) -> Self {
      Self(role: .user, content: content, images: images, audio: audio)
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

    /// Creates a tool message.
    ///
    /// Use this initializer when providing tool output to the model.
    ///
    /// - Parameters:
    ///   - content: The tool output content.
    ///   - name: The name of the tool that produced this output.
    /// - Returns: A ``CactusModel/Message``.
    public static func tool(_ content: String, name: String) -> Self {
      Self(role: .tool, content: content, name: name)
    }

    /// Creates a function message.
    ///
    /// This is an alias for ``tool(_:name:)``.
    ///
    /// - Parameters:
    ///   - content: The function output content.
    ///   - name: The name of the function that produced this output.
    /// - Returns: A ``CactusModel/Message``.
    public static func function(_ content: String, name: String) -> Self {
      Self(role: .function, content: content, name: name)
    }

    /// The ``Role`` of the message.
    public var role: Role

    /// The message content.
    public var content: String

    /// An array of `URL`s to locally stored images.
    public var images: [URL]?

    /// An array of `URL`s to locally stored audio files.
    public var audio: [URL]?

    /// The name of the tool or function that produced this message.
    ///
    /// This is used for messages with the ``Role/tool`` or ``Role/function`` role.
    public var name: String?

    /// Creates a message.
    ///
    /// - Parameters:
    ///   - role: The ``Role`` of the message.
    ///   - content: The message content.
    ///   - images: An array of `URL`s to locally stored images.
    ///   - audio: An array of `URL`s to locally stored audio files.
    ///   - name: The name of the tool or function that produced this message.
    public init(
      role: Role,
      content: String,
      images: [URL]? = nil,
      audio: [URL]? = nil,
      name: String? = nil
    ) {
      self.role = role
      self.content = content
      self.images = images
      self.audio = audio
      self.name = name
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
