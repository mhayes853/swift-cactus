import Foundation

// MARK: - Properties

extension CactusLanguageModel {
  public struct Properties: Hashable, Sendable {
    public var vocabularySize: Int
    public var beginningOfSequenceTokenId: UInt32
    public var endOfSequenceTokenId: UInt32
    public var layerCount: Int
    public var hiddenDimensions: Int
    public var ffnIntermediateDimensions: Int
    public var attentionHeads: Int
    public var attentionKVHeads: Int
    public var attentionHeadDimensions: Int
    public var layerNormEpsilon: Double
    public var ropeTheta: Double
    public var expertCount: Int
    public var sharedExpertCount: Int
    public var topExpertCount: Int
    public var moeEveryNLayers: Int
    public var shouldTieWordEmbeddings: Bool
    public var contextLength: Int
    public var modelType: ModelType
    public var precision: Precision

    public init(
      vocabularySize: Int,
      beginningOfSequenceTokenId: UInt32 = 151643,
      endOfSequenceTokenId: UInt32 = 151645,
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
      contextLength: Int,
      modelType: ModelType,
      precision: Precision
    ) {
      self.vocabularySize = vocabularySize
      self.beginningOfSequenceTokenId = beginningOfSequenceTokenId
      self.endOfSequenceTokenId = endOfSequenceTokenId
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
      self.contextLength = contextLength
    }
  }
}

extension CactusLanguageModel.Properties {
  public init(contentsOf url: URL) throws {
    self.init(rawData: try Data(contentsOf: url))
  }

  public init(rawData: Data) {
    let configData = ModelConfigData(rawData: rawData)
    self.init(
      vocabularySize: configData.integer(forKey: "vocab_size") ?? 151936,
      layerCount: configData.integer(forKey: "num_layers") ?? 28,
      hiddenDimensions: configData.integer(forKey: "hidden_dim") ?? 1024,
      ffnIntermediateDimensions: configData.integer(forKey: "ffn_intermediate_dim") ?? 3072,
      attentionHeads: configData.integer(forKey: "attention_heads") ?? 16,
      attentionKVHeads: configData.integer(forKey: "attention_kv_heads") ?? 8,
      attentionHeadDimensions: configData.integer(forKey: "attention_head_dim") ?? 128,
      layerNormEpsilon: configData.double(forKey: "layer_norm_eps") ?? 1e-6,
      ropeTheta: configData.double(forKey: "rope_theta") ?? 1000000.0,
      expertCount: configData.integer(forKey: "num_experts") ?? 0,
      sharedExpertCount: configData.integer(forKey: "shared_experts") ?? 0,
      topExpertCount: configData.integer(forKey: "top_experts") ?? 0,
      moeEveryNLayers: configData.integer(forKey: "moe_every_n_layers") ?? 0,
      shouldTieWordEmbeddings: configData.boolean(forKey: "tie_word_embeddings") ?? false,
      contextLength: configData.integer(forKey: "context_length") ?? 32768,
      modelType: configData.modelType(forKey: "model_type"),
      precision: configData.precision(forKey: "precision")
    )
  }
}

extension ModelConfigData {
  fileprivate func modelType(forKey key: String) -> CactusLanguageModel.ModelType {
    switch self.string(forKey: "model_type")?.lowercased() {
    case "gemma": .gemma
    case "bert": .nomic
    case "smol": .smol
    default: .qwen
    }
  }

  fileprivate func precision(forKey key: String) -> CactusLanguageModel.Precision {
    switch self.string(forKey: key)?.lowercased() {
    case "int4": .int4
    case "int8": .int8
    case "fp16": .fp16
    default: .fp32
    }
  }
}

// MARK: - Precision

extension CactusLanguageModel {
  public struct Precision: Hashable, Sendable {
    public var bits: Int
    public var isFloatingPoint: Bool

    public init(bits: Int, isFloatingPoint: Bool) {
      self.bits = bits
      self.isFloatingPoint = isFloatingPoint
    }

    public static let int4 = Self(bits: 4, isFloatingPoint: false)
    public static let int8 = Self(bits: 8, isFloatingPoint: false)
    public static let fp16 = Self(bits: 16, isFloatingPoint: true)
    public static let fp32 = Self(bits: 32, isFloatingPoint: true)
  }
}

// MARK: - ModelType

extension CactusLanguageModel {
  public struct ModelType: Hashable, Sendable, Codable {
    public var identifier: String
    public var defaultTemperature: Double
    public var defaultTopP: Double
    public var defaultTopK: Int

    public init(
      identifier: String,
      defaultTemperature: Double,
      defaultTopP: Double,
      defaultTopK: Int
    ) {
      self.identifier = identifier
      self.defaultTemperature = defaultTemperature
      self.defaultTopP = defaultTopP
      self.defaultTopK = defaultTopK
    }

    public static let qwen = Self(
      identifier: "qwen",
      defaultTemperature: 0.6,
      defaultTopP: 0.95,
      defaultTopK: 20
    )

    public static let gemma = Self(
      identifier: "gemma",
      defaultTemperature: 1.0,
      defaultTopP: 0.95,
      defaultTopK: 64
    )

    public static let smol = Self(
      identifier: "smol",
      defaultTemperature: 0.2,
      defaultTopP: 0.95,
      defaultTopK: 20
    )

    public static let nomic = Self(
      identifier: "bert",
      defaultTemperature: 0.6,
      defaultTopP: 0.95,
      defaultTopK: 20
    )
  }
}
