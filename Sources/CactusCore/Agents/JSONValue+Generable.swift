import Foundation

// MARK: - ConvertibleToJSONValue

public protocol ConvertibleToJSONValue: CactusPromptRepresentable {
  associatedtype JSONFailure: Error

  var jsonValue: JSONValue { get throws(JSONFailure) }
}

extension ConvertibleToJSONValue {
  public var promptContent: CactusPromptContent {
    get throws {
      let data = try PromptContentEncoder.current.encode(self.jsonValue)
      return CactusPromptContent(text: String(decoding: data, as: UTF8.self))
    }
  }
}

// MARK: - ConvertibleFromJSONValue

public protocol ConvertibleFromJSONValue: ConvertibleFromCactusResponse {
  associatedtype JSONFailure: Error
  init(jsonValue: JSONValue) throws(JSONFailure)
}

extension ConvertibleFromJSONValue {
  public init(cactusResponse: String) throws {
    fatalError("TODO")
  }
}

// MARK: - Combined Protocols

extension JSONValue {
  public typealias Convertible = ConvertibleToJSONValue & ConvertibleFromJSONValue

  public protocol Generable: Convertible {
    static var jsonSchema: JSONSchema { get }
  }
}

// MARK: - JSONValue

extension JSONValue: ConvertibleToJSONValue {
  public var jsonValue: JSONValue {
    self
  }
}

extension JSONValue: ConvertibleFromJSONValue {
  public init(jsonValue: JSONValue) {
    self = jsonValue
  }
}
