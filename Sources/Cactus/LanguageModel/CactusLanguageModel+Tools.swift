// MARK: - ToolDefinition

extension CactusLanguageModel {
  /// The definition for a tool invoked by a ``CactusLanguageModel``.
  public struct ToolDefinition: Hashable, Sendable, Codable {
    /// The name of the tool.
    public var name: String

    /// The description of the functionallity that the tool provides.
    public var description: String

    /// The parameters used by the tool.
    public var parameters: Parameters

    /// Creates a tool definition.
    ///
    /// - Parameters:
    ///   - name: The name of the tool.
    ///   - description: The description of the functionallity that the tool provides.
    ///   - parameters: The parameters used by the tool.
    public init(name: String, description: String, parameters: Parameters) {
      self.name = name
      self.description = description
      self.parameters = parameters
    }
  }
}

// MARK: - Parameters

extension CactusLanguageModel.ToolDefinition {
  /// A set of parameters used by a tool.
  public struct Parameters: Hashable, Sendable, Codable {
    public private(set) var type = CactusLanguageModel.SchemaType.object

    /// A list of names indicating the required parameters.
    public var required: [String]

    /// A dictionary of parameters.
    public var properties: [String: Parameter]

    /// Creayes a parameter set.
    ///
    /// - Parameters:
    ///   - properties: A list of names indicating the required parameters.
    ///   - required: A dictionary of parameters.
    public init(properties: [String: Parameter], required: [String]) {
      self.required = required
      self.properties = properties
    }
  }
}

// MARK: - Parameter

extension CactusLanguageModel.ToolDefinition {
  /// A parameter for a tool.
  public struct Parameter: Hashable, Sendable, Codable {
    /// The ``CactusLanguageModel/SchemaType`` of the parameter.
    public var type: CactusLanguageModel.SchemaType

    /// A description of the parameter.
    public var description: String

    /// Creates a parameter.
    ///
    /// - Parameters:
    ///   - type: The ``CactusLanguageModel/SchemaType`` of the parameter.
    ///   - description: A description of the parameter.
    public init(type: CactusLanguageModel.SchemaType, description: String) {
      self.type = type
      self.description = description
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
    public var arguments: [String: SchemaValue]

    /// Creates a tool call.
    ///
    /// - Parameters:
    ///   - name: The name of the tool that was invoked.
    ///   - arguments: The arguments that the tool was invoked with.
    public init(name: String, arguments: [String: CactusLanguageModel.SchemaValue]) {
      self.name = name
      self.arguments = arguments
    }
  }
}
