import Foundation

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
      vocabularySize: file.vocabularySize ?? 151936,
      layerCount: file.layerCount ?? 28,
      hiddenDimensions: file.hiddenDimensions ?? 1024,
      ffnIntermediateDimensions: file.ffnIntermediateDimensions ?? 3072,
      attentionHeads: file.attentionHeads ?? 16,
      attentionKVHeads: file.attentionKVHeads ?? 8,
      attentionHeadDimensions: file.attentionHeadDimensions ?? 128,
      layerNormEpsilon: file.layerNormEpsilon ?? 1e-6,
      ropeTheta: file.ropeTheta ?? 1000000.0,
      expertCount: file.expertCount ?? 0,
      sharedExpertCount: file.sharedExpertCount ?? 0,
      topExpertCount: file.topExpertCount ?? 0,
      moeEveryNLayers: file.moeEveryNLayers ?? 0,
      shouldTieWordEmbeddings: file.shouldTieWordEmbeddings ?? false,
      contextLengthTokens: file.contextLengthTokens ?? 32768,
      modelType: file.modelType ?? .qwen,
      precision: file.precision ?? .fp32
    )
  }
}
