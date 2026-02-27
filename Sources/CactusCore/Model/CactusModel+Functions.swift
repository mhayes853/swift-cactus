// MARK: - FunctionDefinition

extension CactusModel {
  /// The definition for a function invoked by a ``CactusModel``.
  public struct FunctionDefinition: Hashable, Sendable, Codable {
    /// The name of the function.
    public var name: String

    /// The description of the functionallity that the function provides.
    public var description: String

    /// A ``JSONSchema`` for the parameters of this function.
    ///
    /// > Notice: The language model isn't guaranteed to generate values that are valid with this
    /// > schema. If validity matters, you can manually validate the output using
    /// > ``JSONSchema/Validator``.
    public var parameters: JSONSchema

    /// Creates a function definition.
    ///
    /// - Parameters:
    ///   - name: The name of the function.
    ///   - description: The description of the functionallity that the function provides.
    ///   - parameters: The parameters used by the function.
    public init(name: String, description: String, parameters: JSONSchema) {
      self.name = name
      self.description = description
      self.parameters = parameters
    }
  }
}

// MARK: - FunctionCall

extension CactusModel {
  /// A function call from a ``CactusModel``.
  public struct FunctionCall: Hashable, Sendable, Codable {
    /// The name of the function that was invoked.
    public var name: String

    /// The arguments that the function was invoked with.
    ///
    /// > Notice: The language model isn't guaranteed to generate a values that are valid with
    /// > function definition parameters If validity matters, you can manually validate the output
    /// > using ``JSONSchema/Validator``.
    public var arguments: [String: JSONSchema.Value]

    /// Creates a function call.
    ///
    /// - Parameters:
    ///   - name: The name of the function that was invoked.
    ///   - arguments: The arguments that the function was invoked with.
    public init(name: String, arguments: [String: JSONSchema.Value]) {
      self.name = name
      self.arguments = arguments
    }
  }
}
