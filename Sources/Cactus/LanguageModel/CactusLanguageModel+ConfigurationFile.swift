import Foundation

// MARK: - ConfigurationFile

extension CactusLanguageModel {
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

    public func string(forKey key: String) -> String? {
      self.items[Substring(key)].map { String($0) }
    }

    public func integer(forKey key: String) -> Int? {
      self.string(forKey: key).flatMap { Int($0) }
    }

    public func double(forKey key: String) -> Double? {
      self.string(forKey: key).flatMap { Double($0) }
    }

    public func boolean(forKey key: String) -> Bool? {
      self.string(forKey: key).flatMap { Bool($0) }
    }
  }
}

// MARK: - Precision

extension CactusLanguageModel {
  /// The precision of a model's weights and activation values.
  public struct Precision: Hashable, Sendable {
    /// The number of bits used to represent each weight or activation value.
    public let bits: Int

    /// Whether or not the precision format is a floating point format.
    public let isFloatingPoint: Bool

    /// Creates a precision.
    ///
    /// - Parameters:
    ///   - bits: The number of bits used to represent each weight.
    ///   - isFloatingPoint: Whether or not the precision format is a floating point format.
    public init(bits: Int, isFloatingPoint: Bool) {
      self.bits = bits
      self.isFloatingPoint = isFloatingPoint
    }

    /// INT4 precision.
    public static let int4 = Self(bits: 4, isFloatingPoint: false)

    /// INT8 precision.
    public static let int8 = Self(bits: 8, isFloatingPoint: false)

    /// FP16 precision.
    public static let fp16 = Self(bits: 16, isFloatingPoint: true)

    /// FP32 precision.
    public static let fp32 = Self(bits: 32, isFloatingPoint: true)
  }
}

// MARK: - ModelType

extension CactusLanguageModel {
  /// The type of a model.
  public struct ModelType: Hashable, Sendable, Codable {
    /// A named identifier for the model (eg. `"gemma"`).
    public var identifier: String

    /// The default temperature to use for chat completions.
    public var defaultTemperature: Float

    /// The default nucleus sampling to use for chat completions.
    public var defaultTopP: Float

    /// The default k most probable options to limit the next word to.
    public var defaultTopK: Int

    /// Creates a model type.
    ///
    /// - Parameters:
    ///   - identifier: A named identifier for the model (eg. `"gemma"`).
    ///   - defaultTemperature: The default temperature to use for chat completions.
    ///   - defaultTopP: The default nucleus sampling to use for chat completions.
    ///   - defaultTopK: The default k most probable options to limit the next word to.
    public init(
      identifier: String,
      defaultTemperature: Float,
      defaultTopP: Float,
      defaultTopK: Int
    ) {
      self.identifier = identifier
      self.defaultTemperature = defaultTemperature
      self.defaultTopP = defaultTopP
      self.defaultTopK = defaultTopK
    }

    /// A model type for qwen models.
    public static let qwen = Self(
      identifier: "qwen",
      defaultTemperature: 0.6,
      defaultTopP: 0.95,
      defaultTopK: 20
    )

    /// A model type for gemma models.
    public static let gemma = Self(
      identifier: "gemma",
      defaultTemperature: 1.0,
      defaultTopP: 0.95,
      defaultTopK: 64
    )

    /// A model type for smol models.
    public static let smol = Self(
      identifier: "smol",
      defaultTemperature: 0.2,
      defaultTopP: 0.95,
      defaultTopK: 20
    )

    /// A model type for nomic models.
    public static let nomic = Self(
      identifier: "bert",
      defaultTemperature: 0.6,
      defaultTopP: 0.95,
      defaultTopK: 20
    )

    /// A model type for lfm2 models.
    public static let lfm2 = Self(
      identifier: "lfm2",
      defaultTemperature: 0.3,
      defaultTopP: 0.95,
      defaultTopK: 20
    )
  }
}
