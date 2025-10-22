import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusLanguageModelProperties tests` {
  @Test
  func `Reads Raw Config Data`() {
    let data = Data(
      """
      # Gemma3 270m
      vocab_size=262144
      hidden_dim=640
      num_layers=18
      attention_heads=4


        attention_kv_heads=1

      skjhjkhskjhks

      unrelated=unrelated

      ffn_intermediate_dim=2048
      context_length=32768
      rope_theta=1000000.0
      attention_head_dim=256
      tie_word_embeddings=true
      model_type=gemma
      precision=FP16
      """
      .utf8
    )
    let properties = CactusLanguageModel.Properties(rawData: data)
    let expectedProperties = CactusLanguageModel.Properties(
      vocabularySize: 262144,
      layerCount: 18,
      hiddenDimensions: 640,
      ffnIntermediateDimensions: 2048,
      attentionHeads: 4,
      attentionKVHeads: 1,
      attentionHeadDimensions: 256,
      layerNormEpsilon: 1e-6,
      ropeTheta: 1000000.0,
      expertCount: 0,
      sharedExpertCount: 0,
      topExpertCount: 0,
      moeEveryNLayers: 0,
      shouldTieWordEmbeddings: true,
      contextLengthTokens: 32768,
      modelType: .gemma,
      precision: .fp16
    )
    expectNoDifference(properties, expectedProperties)
  }
}
