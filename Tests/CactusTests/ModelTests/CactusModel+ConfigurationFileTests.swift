import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusModelConfigurationFile tests` {
  @Test
  @available(*, deprecated)
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
      use_image_tokens=1
      """
      .utf8
    )
    let file = CactusModel.ConfigurationFile(rawData: data)
    expectNoDifference(file.vocabularySize, 262144)
    expectNoDifference(file.layerCount, 18)
    expectNoDifference(file.hiddenDimensions, 640)
    expectNoDifference(file.attentionHeads, 4)
    expectNoDifference(file.attentionKVHeads, 1)
    expectNoDifference(file.attentionHeadDimensions, 256)
    expectNoDifference(file.ffnIntermediateDimensions, 2048)
    expectNoDifference(file.contextLengthTokens, 32768)
    expectNoDifference(file.shouldTieWordEmbeddings, true)
    expectNoDifference(file.modelType, .gemma)
    expectNoDifference(file.precision, .fp16)
    expectNoDifference(file.ropeTheta, 1000000.0)
    expectNoDifference(file.isUsingImageTokens, true)

    expectNoDifference(file.layerNormEpsilon, nil)
  }
}
