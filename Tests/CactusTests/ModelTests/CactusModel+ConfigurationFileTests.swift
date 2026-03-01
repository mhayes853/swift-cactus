import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusModelConfigurationFile tests` {
  @Test
  func `Reads model identifier from config`() {
    let data = Data(
      """
      model_type=gemma
      """
      .utf8
    )
    let file = CactusModel.ConfigurationFile(rawData: data)
    expectNoDifference(file.modelIdentifier, .gemma)
  }
}
