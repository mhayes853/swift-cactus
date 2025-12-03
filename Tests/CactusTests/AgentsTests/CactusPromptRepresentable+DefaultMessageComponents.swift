import Cactus

extension CactusPromptRepresentable {
  func defaultMessageComponents() throws -> CactusPromptContent.MessageComponents {
    try self.promptContent(in: CactusEnvironmentValues())
      .messageComponents(in: CactusEnvironmentValues())
  }
}
