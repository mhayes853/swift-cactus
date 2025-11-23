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
      self.string(forKey: key).flatMap { (Bool($0) ?? false) || $0 == "1" }
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
      switch self.string(forKey: "model_type")?.lowercased() {
      case "gemma": .gemma
      case "bert": .nomic
      case "smol": .smol
      case "lfm2": .lfm2
      case "qwen": .qwen
      default: nil
      }
    }

    /// The ``CactusLanguageModel/Precision`` of the model.
    public var precision: Precision? {
      switch self.string(forKey: "precision")?.lowercased() {
      case "int4": .int4
      case "int8": .int8
      case "fp16": .fp16
      default: nil
      }
    }

    /// The ``CactusLanguageModel/ModelVariant`` of the model.
    public var modelVariant: ModelVariant {
      switch self.string(forKey: "model_variant")?.lowercased() {
      case "vlm": .vlm
      case "extract": .extract
      case "rag": .rag
      default: .default
      }
    }

    /// The dimensionality of hidden representations in the vision encoder.
    public var visionHiddenDimensions: Int? {
      self.integer(forKey: "vision_hidden_dim")
    }

    /// The number of layers in the vision encoder.
    public var visionLayerCount: Int? {
      self.integer(forKey: "vision_num_layers")
    }

    /// The number of attention heads used in each vision encoder layer.
    public var visionAttentionHeads: Int? {
      self.integer(forKey: "vision_attention_heads")
    }

    /// The input image size.
    public var visionImageSize: Int? {
      self.integer(forKey: "vision_image_size")
    }

    /// The side length of each square patch used by the vision patch embedding layer.
    public var visionPatchSize: Int? {
      self.integer(forKey: "vision_patch_size")
    }

    /// The number of input channels to the vision encoder (eg. `3` for RGB).
    public var visionChannelCount: Int? {
      self.integer(forKey: "vision_num_channels")
    }

    /// The dimensionality of the visual embedding space produced by the patch embedding layer.
    public var visionEmbedDimensions: Int? {
      self.integer(forKey: "vision_embed_dim")
    }

    /// The number of visual tokens generated for each image after patching and preprocessing.
    public var visionTokensPerImage: Int? {
      self.integer(forKey: "vision_tokens_per_img")
    }

    /// Indicates whether pixel shuffle upsampling is used in the vision pipeline.
    public var isUsingPixelShuffle: Bool? {
      self.boolean(forKey: "use_pixel_shuffle")
    }

    /// The spatial upsampling factor used when applying pixel shuffle.
    public var pixelShuffleFactor: Int? {
      self.integer(forKey: "pixel_shuffle_factor")
    }

    /// Indicates whether the model inserts explicit `<image>` tokens into the text sequence.
    public var isUsingImageTokens: Bool? {
      self.boolean(forKey: "use_image_tokens")
    }

    /// Indicates whether layout tags are used to describe document structure.
    public var isUsingLayoutTags: Bool? {
      self.boolean(forKey: "use_layout_tags")
    }

    /// The maximum number of sequence positions reserved for image features.
    public var imageSequenceLength: Int? {
      self.integer(forKey: "image_seq_len")
    }

    /// The size of a global image view used alongside tiles.
    public var globalImageSize: Int? {
      self.integer(forKey: "global_image_size")
    }

    /// The maximum tile side length when splitting large images into smaller regions.
    public var maxTileSize: Int? {
      self.integer(forKey: "max_tile_size")
    }

    /// A scaling factor applied when resizing or normalizing images for the vision encoder.
    public var rescaleFactor: Double? {
      self.double(forKey: "rescale_factor")
    }

    /// The mean value used to normalize image pixel intensities.
    public var imageMean: Double? {
      self.double(forKey: "image_mean")
    }

    /// The standard deviation used to normalize image pixel intensities.
    public var imageStd: Double? {
      self.double(forKey: "image_std")
    }

    /// The integer factor by which the input image is downsampled before encoding.
    public var downsampleFactor: Int? {
      self.integer(forKey: "downsample_factor")
    }

    /// The minimum number of tiles to generate when splitting an image.
    public var minTiles: Int? {
      self.integer(forKey: "min_tiles")
    }

    /// The maximum number of tiles to generate when splitting an image.
    public var maxTiles: Int? {
      self.integer(forKey: "max_tiles")
    }

    /// Indicates whether a low-resolution thumbnail view of the image is used.
    public var isUsingThumbnail: Bool? {
      self.boolean(forKey: "use_thumbnail")
    }

    /// The minimum number of image tokens required for a valid visual input.
    public var minImageTokens: Int? {
      self.integer(forKey: "min_image_tokens")
    }

    /// The maximum number of image tokens the model is allowed to attend to for a single image.
    public var maxImageTokens: Int? {
      self.integer(forKey: "max_image_tokens")
    }

    /// The maximum number of image patches that can be produced when tiling.
    public var maxPatchesCount: Int? {
      self.integer(forKey: "max_num_patches")
    }

    /// The side length of each tile when splitting an image into a grid.
    public var tileSize: Int? {
      self.integer(forKey: "tile_size")
    }

    /// The allowed relative error in total pixel coverage when approximating the image with tiles.
    public var maxPixelsTolerance: Double? {
      self.double(forKey: "max_pixels_tolerance")
    }

    /// Indicates whether the image can be split into multiple tiles instead of using a single global view.
    public var isImageSplitting: Bool? {
      self.boolean(forKey: "do_image_splitting")
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

// MARK: - ModelVariant

extension CactusLanguageModel {
  /// A variant of language model.
  public struct ModelVariant: RawRepresentable, Hashable, Sendable {
    /// A visual language model.
    public static let vlm = Self(rawValue: "vlm")

    /// A RAG model.
    public static let rag = Self(rawValue: "rag")

    /// An extract model.
    public static let extract = Self(rawValue: "extract")

    /// The default model variant.
    public static let `default` = Self(rawValue: "default")

    public var rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}
