@resultBuilder
public enum CactusAgentBuilder<Input: CactusPromptRepresentable, Output: ConvertibleFromJSONValue> {
  public static func buildArray<A: CactusAgent<Input, Output>>(
    _ components: [A]
  ) -> _ChainedAgent<A> {
    _ChainedAgent(components)
  }

  public static func buildBlock() -> EmptyAgent<Input, Output> {
    EmptyAgent()
  }
}

public struct _ChainedAgent<Agent: CactusAgent>: CactusAgent {
  let agents: [Agent]

  init(_ agents: [Agent]) {
    self.agents = agents
  }

  public func stream(
    isolation: isolated (any Actor)?,
    input: Agent.Input,
    into continuation: CactusAgentStream<Agent.Output>.Continuation
  ) async throws {
    fatalError()
  }
}
