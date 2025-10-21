// MARK: - ToolDefinition

extension CactusLanguageModel {
  /// The definition for a tool invoked by a ``CactusLanguageModel``.
  public struct ToolDefinition: Hashable, Sendable, Codable {
    /// The name of the tool.
    public var name: String

    /// The description of the functionallity that the tool provides.
    public var description: String

    /// A ``JSONSchema`` for the parameters of this tool.
    ///
    /// > Notice: The language model isn't guaranteed to generate values that are valid with this
    /// > schema. If validity matters, you can manually validate the output using
    /// > ``JSONSchema/Validator``.
    public var parameters: JSONSchema

    /// Creates a tool definition.
    ///
    /// - Parameters:
    ///   - name: The name of the tool.
    ///   - description: The description of the functionallity that the tool provides.
    ///   - parameters: The parameters used by the tool.
    public init(name: String, description: String, parameters: JSONSchema) {
      self.name = name
      self.description = description
      self.parameters = parameters
    }
  }
}

// MARK: - ToolCall

extension CactusLanguageModel {
  /// A tool call from a ``CactusLanguageModel``.
  public struct ToolCall: Hashable, Sendable, Codable {
    /// The name of the tool that was invoked.
    public var name: String

    /// The arguments that the tool was invoked with.
    ///
    /// > Notice: The language model isn't guaranteed to generate a values that are valid with
    /// > tool definition parameters If validity matters, you can manually validate the output
    /// > using ``JSONSchema/Validator``.
    public var arguments: [String: JSONSchema.Value]

    /// Creates a tool call.
    ///
    /// - Parameters:
    ///   - name: The name of the tool that was invoked.
    ///   - arguments: The arguments that the tool was invoked with.
    public init(name: String, arguments: [String: JSONSchema.Value]) {
      self.name = name
      self.arguments = arguments
    }
  }
}
