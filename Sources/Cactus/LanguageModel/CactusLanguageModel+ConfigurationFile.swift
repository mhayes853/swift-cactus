import Foundation

// MARK: - ConfigurationFile

extension CactusLanguageModel {
  // A data type describing properties from a model's `config.txt` file.
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
      self.string(forKey: key).flatMap { Bool($0) }
    }

    /// The size of the model vocabulary.
    public var vocabularySize: Int? {
      self.integer(forKey: "vocab_size")
    }

    /// The number of layers.
    public var layerCount: Int? {
      self.integer(forKey: "num_layers")
    }

    /// The number of hidden dimenstions.
    public var hiddenDimensions: Int? {
      self.integer(forKey: "hidden_dim")
    }

    /// The number of intermediate dimensions in the model’s feed-forward network.
    public var ffnIntermediateDimensions: Int? {
      self.integer(forKey: "ffn_intermediate_dim")
    }

    /// The total number of attention heads used per layer.
    public var attentionHeads: Int? {
      self.integer(forKey: "attention_heads")
    }

    /// The number of key-value heads.
    public var attentionKVHeads: Int? {
      self.integer(forKey: "attention_kv_heads")
    }

    /// The dimensionality of each attention head.
    public var attentionHeadDimensions: Int? {
      self.integer(forKey: "attention_head_dim")
    }

    /// The epsilon value used to prevent division by zero during layer normalization.
    public var layerNormEpsilon: Double? {
      self.double(forKey: "layer_norm_eps")
    }

    /// The scaling factor (θ) used for Rotary Position Embeddings.
    public var ropeTheta: Double? {
      self.double(forKey: "rope_theta")
    }

    /// The total number of experts available in a Mixture-of-Experts layer.
    public var expertCount: Int? {
      self.integer(forKey: "num_experts")
    }

    /// The number of experts shared across all Mixture-of-Experts layers.
    public var sharedExpertCount: Int? {
      self.integer(forKey: "shared_experts")
    }

    /// The number of top experts selected per token during routing.
    public var topExpertCount: Int? {
      self.integer(forKey: "top_experts")
    }

    /// The frequency (in layers) at which Mixture-of-Experts layers appear in the model.
    public var moeEveryNLayers: Int? {
      self.integer(forKey: "moe_every_n_layers")
    }

    /// Whether the model should tie word embeddings.
    public var shouldTieWordEmbeddings: Bool? {
      self.boolean(forKey: "tie_word_embeddings")
    }

    /// The maximum context length (in tokens) that the model can attend to.
    public var contextLengthTokens: Int? {
      self.integer(forKey: "context_length")
    }

    /// The ``CactusLanguageModel/ModelType`` of the model.
    public var modelType: ModelType? {
      self.modelType(forKey: "model_type")
    }

    /// The ``CactusLanguageModel/Precision`` of the model.
    public var precision: Precision? {
      self.precision(forKey: "precision")
    }

    private func modelType(forKey key: String) -> CactusLanguageModel.ModelType? {
      switch self.string(forKey: key)?.lowercased() {
      case "gemma": .gemma
      case "bert": .nomic
      case "smol": .smol
      default: nil
      }
    }

    private func precision(forKey key: String) -> CactusLanguageModel.Precision? {
      switch self.string(forKey: key)?.lowercased() {
      case "int4": .int4
      case "int8": .int8
      case "fp16": .fp16
      default: nil
      }
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
