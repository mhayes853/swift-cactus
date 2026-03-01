import Foundation

// MARK: - ConfigurationFile

extension CactusModel {
  /// A data type describing properties from a model's `config.txt` file.
  public struct ConfigurationFile: Sendable {
    private var items = [Substring: Substring]()

    /// Reads the properties from a model configuration file.
    ///
    /// The path of this file is typically located in `<model-folder>/config.txt`.
    ///
    /// - Parameter url: The `URL` of the model config file.
    public init(contentsOf url: URL) throws {
      self.init(rawData: try Data(contentsOf: url))
    }

    /// Reads the properties from in-memory configuration file data.
    ///
    /// - Parameter rawData: The raw data of the model's `config.txt` file.
    public init(rawData: Data) {
      let stringified = String(decoding: rawData, as: UTF8.self)
      for line in stringified.split(separator: "\n") {
        let line = line.trimmingCharacters(in: .whitespaces)
        guard !line.starts(with: "#") else { continue }
        let splits = line.split(separator: "=")
        guard splits.count == 2 else { continue }
        self.items[splits[0]] = splits[1]
      }
    }

    /// Returns a string value for the specified `key`.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: A String value, or `nil` if the key is not found.
    public func string(forKey key: String) -> String? {
      self.items[Substring(key)].map { String($0) }
    }

    /// Returns an integer value for the specified `key`.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: An integer value, or `nil` if the value cannot be converted to an integer.
    public func integer(forKey key: String) -> Int? {
      self.string(forKey: key).flatMap { Int($0) }
    }

    /// Returns a double value for the specified `key`.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: A double value, or `nil` if the value cannot be converted to a double.
    public func double(forKey key: String) -> Double? {
      self.string(forKey: key).flatMap { Double($0) }
    }

    /// Returns a boolean value for the specified `key`.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: A boolean value, or `nil` if the value cannot be converted to a boolean.
    public func boolean(forKey key: String) -> Bool? {
      self.string(forKey: key).flatMap { (Bool($0) ?? false) || $0 == "1" }
    }

    /// The ``CactusModel/ModelIdentifier`` of the model.
    public var modelIdentifier: ModelIdentifier? {
      switch self.string(forKey: "model_type")?.lowercased() {
      case "gemma": .gemma
      case "bert": .nomic
      case "smol": .smol
      case "lfm2": .lfm2
      case "qwen": .qwen
      case "moonshine": .moonshine
      case "whisper": .whisper
      case "parakeet": .parakeet
      default: nil
      }
    }
  }
}

// MARK: - ModelIdentifier

extension CactusModel {
  /// A string-based identifier for a model type.
  public struct ModelIdentifier: RawRepresentable, Hashable, Sendable, Codable {
    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }

    /// A model identifier for Qwen models.
    public static let qwen = Self(rawValue: "qwen")

    /// A model identifier for Gemma models.
    public static let gemma = Self(rawValue: "gemma")

    /// A model identifier for Smol models.
    public static let smol = Self(rawValue: "smol")

    /// A model identifier for Nomic (BERT) models.
    public static let nomic = Self(rawValue: "bert")

    /// A model identifier for LFM2 models.
    public static let lfm2 = Self(rawValue: "lfm2")

    /// A model identifier for Whisper models.
    public static let whisper = Self(rawValue: "whisper")

    /// A model identifier for Parakeet models.
    public static let parakeet = Self(rawValue: "parakeet")

    /// A model identifier for Moonshine models.
    public static let moonshine = Self(rawValue: "moonshine")
  }
}
