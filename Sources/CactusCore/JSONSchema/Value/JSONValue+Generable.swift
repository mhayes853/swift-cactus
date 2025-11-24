// MARK: - ConvertibleToJSONValue

public protocol ConvertibleToJSONValue: CactusPromptRepresentable {
  var jsonValue: JSONValue { get }
}

extension ConvertibleToJSONValue {
  public var promptContent: CactusPromptContent {
    fatalError()
  }
}

// MARK: - ConvertibleFromJSONValue

public protocol ConvertibleFromJSONValue {
  associatedtype JSONFailure: Error
  init(jsonValue: JSONValue) throws(JSONFailure)
}

// MARK: - Combined Protocols

extension JSONValue {
  public typealias Convertible = ConvertibleToJSONValue & ConvertibleFromJSONValue

  public protocol Generable: Convertible {
    static var jsonSchema: JSONSchema { get }
  }
}
