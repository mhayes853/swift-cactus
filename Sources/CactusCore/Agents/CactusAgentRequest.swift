public struct CactusAgentRequest<Input: CactusPromptRepresentable> {
  public var input: Input
  public var environment: CactusEnvironmentValues

  public init(input: Input, environment: CactusEnvironmentValues = CactusEnvironmentValues()) {
    self.input = input
    self.environment = environment
  }
}
