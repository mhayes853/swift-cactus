import Cactus

extension CactusPromptRepresentable {
  func defaultMessageComponents() throws -> CactusMessageComponents {
    try self.promptContent(in: CactusEnvironmentValues())
      .messageComponents(in: CactusEnvironmentValues())
  }
}
