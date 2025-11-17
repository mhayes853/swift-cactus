import Foundation

// MARK: - Properties

extension CactusLanguageModel {
  /// A data type describing properties of a model.
  ///
  /// Generally, this information comes from the `config.txt` file inside the model's directory.
  @available(*, deprecated, message: "Use `CactusLanguageModel.ConfigurationFile` instead.")
  public struct Properties: Hashable, Sendable {
    /// The size of the model vocabulary.
    public var vocabularySize: Int

    /// The number of layers.
    public var layerCount: Int

    /// The number of hidden dimenstions.
    public var hiddenDimensions: Int

    /// The number of intermediate dimensions in the model’s feed-forward network.
    public var ffnIntermediateDimensions: Int

    /// The total number of attention heads used per layer.
    public var attentionHeads: Int

    /// The number of key-value heads.
    public var attentionKVHeads: Int

    /// The dimensionality of each attention head.
    public var attentionHeadDimensions: Int

    /// The epsilon value used to prevent division by zero during layer normalization.
    public var layerNormEpsilon: Double

    /// The scaling factor (θ) used for Rotary Position Embeddings.
    public var ropeTheta: Double

    /// The total number of experts available in a Mixture-of-Experts layer.
    public var expertCount: Int

    /// The number of experts shared across all Mixture-of-Experts layers.
    public var sharedExpertCount: Int

    /// The number of top experts selected per token during routing.
    public var topExpertCount: Int

    /// The frequency (in layers) at which Mixture-of-Experts layers appear in the model.
    public var moeEveryNLayers: Int

    /// Whether the model should tie word embeddings.
    public var shouldTieWordEmbeddings: Bool

    /// The maximum context length (in tokens) that the model can attend to.
    public var contextLengthTokens: Int

    /// The ``CactusLanguageModel/ModelType`` of the model.
    public var modelType: ModelType

    /// The ``CactusLanguageModel/Precision`` of the model.
    public var precision: Precision

    /// Creates model properties.
    ///
    /// - Parameters:
    ///   - vocabularySize: The size of the model vocabulary.
    ///   - layerCount: The number of layers.
    ///   - hiddenDimensions: The number of hidden dimenstions.
    ///   - ffnIntermediateDimensions: The number of intermediate dimensions in the model’s
    ///   feed-forward network.
    ///   - attentionHeads: The total number of attention heads used per layer.
    ///   - attentionKVHeads: The number of key-value heads.
    ///   - attentionHeadDimensions: The dimensionality of each attention head.
    ///   - layerNormEpsilon: The epsilon value used to prevent division by zero during layer
    ///   normalization.
    ///   - ropeTheta: The scaling factor (θ) used for Rotary Position Embeddings.
    ///   - expertCount: The total number of experts available in a Mixture-of-Experts layer.
    ///   - sharedExpertCount: The number of experts shared across all Mixture-of-Experts layers.
    ///   - topExpertCount: The number of top experts selected per token during routing.
    ///   - moeEveryNLayers: The frequency (in layers) at which Mixture-of-Experts layers appear
    ///   in the model.
    ///   - shouldTieWordEmbeddings: Whether the model should tie word embeddings.
    ///   - contextLengthTokens: The maximum context length (in tokens) that the model can attend
    ///   to.
    ///   - modelType: The ``CactusLanguageModel/ModelType`` of the model.
    ///   - precision: The ``CactusLanguageModel/Precision`` of the model.
    public init(
      vocabularySize: Int,
      layerCount: Int,
      hiddenDimensions: Int,
      ffnIntermediateDimensions: Int,
      attentionHeads: Int,
      attentionKVHeads: Int,
      attentionHeadDimensions: Int,
      layerNormEpsilon: Double,
      ropeTheta: Double,
      expertCount: Int,
      sharedExpertCount: Int,
      topExpertCount: Int,
      moeEveryNLayers: Int,
      shouldTieWordEmbeddings: Bool,
      contextLengthTokens: Int,
      modelType: ModelType,
      precision: Precision
    ) {
      self.vocabularySize = vocabularySize
      self.layerCount = layerCount
      self.hiddenDimensions = hiddenDimensions
      self.ffnIntermediateDimensions = ffnIntermediateDimensions
      self.attentionHeads = attentionHeads
      self.attentionKVHeads = attentionKVHeads
      self.attentionHeadDimensions = attentionHeadDimensions
      self.layerNormEpsilon = layerNormEpsilon
      self.ropeTheta = ropeTheta
      self.expertCount = expertCount
      self.sharedExpertCount = sharedExpertCount
      self.topExpertCount = topExpertCount
      self.moeEveryNLayers = moeEveryNLayers
      self.shouldTieWordEmbeddings = shouldTieWordEmbeddings
      self.modelType = modelType
      self.precision = precision
      self.contextLengthTokens = contextLengthTokens
    }
  }
}

@available(*, deprecated)
extension CactusLanguageModel.Properties {
  /// Reads the properties from a model configuration file.
  ///
  /// The path of this file is typically located in `<model-folder>/config.txt`.
  ///
  /// - Parameter url: The `URL` of the model config file.
  public init(contentsOf url: URL) throws {
    self.init(rawData: try Data(contentsOf: url))
  }

  /// Creates model properties from raw model configuration data.
  ///
  /// The path of the file that contains the configuration data is typically located in
  /// `<model-folder>/config.txt`.
  ///
  /// - Parameter rawData: The raw model configuration data.
  public init(rawData: Data) {
    self.init(file: CactusLanguageModel.ConfigurationFile(rawData: rawData))
  }

  init(file: CactusLanguageModel.ConfigurationFile) {
    self.init(
      vocabularySize: file.integer(forKey: "vocab_size") ?? 151936,
      layerCount: file.integer(forKey: "num_layers") ?? 28,
      hiddenDimensions: file.integer(forKey: "hidden_dim") ?? 1024,
      ffnIntermediateDimensions: file.integer(forKey: "ffn_intermediate_dim") ?? 3072,
      attentionHeads: file.integer(forKey: "attention_heads") ?? 16,
      attentionKVHeads: file.integer(forKey: "attention_kv_heads") ?? 8,
      attentionHeadDimensions: file.integer(forKey: "attention_head_dim") ?? 128,
      layerNormEpsilon: file.double(forKey: "layer_norm_eps") ?? 1e-6,
      ropeTheta: file.double(forKey: "rope_theta") ?? 1000000.0,
      expertCount: file.integer(forKey: "num_experts") ?? 0,
      sharedExpertCount: file.integer(forKey: "shared_experts") ?? 0,
      topExpertCount: file.integer(forKey: "top_experts") ?? 0,
      moeEveryNLayers: file.integer(forKey: "moe_every_n_layers") ?? 0,
      shouldTieWordEmbeddings: file.boolean(forKey: "tie_word_embeddings") ?? false,
      contextLengthTokens: file.integer(forKey: "context_length") ?? 32768,
      modelType: file.modelType(forKey: "model_type"),
      precision: file.precision(forKey: "precision") ?? .fp32
    )
  }
}

// MARK: - Helpers

extension CactusLanguageModel.ConfigurationFile {
  fileprivate func modelType(forKey key: String) -> CactusLanguageModel.ModelType {
    switch self.string(forKey: "model_type")?.lowercased() {
    case "gemma": .gemma
    case "bert": .nomic
    case "smol": .smol
    default: .qwen
    }
  }

  fileprivate func precision(forKey key: String) -> CactusLanguageModel.Precision? {
    switch self.string(forKey: key)?.lowercased() {
    case "int4": .int4
    case "int8": .int8
    case "fp16": .fp16
    default: nil
    }
  }
}
