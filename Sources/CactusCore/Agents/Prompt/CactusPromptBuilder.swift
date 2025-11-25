@resultBuilder
public struct CactusPromptBuilder {
  public static func buildBlock<each P: CactusPromptRepresentable>(
    _ components: repeat each P
  ) -> _JoinedPromptContent {
    var contents = [any CactusPromptRepresentable]()
    for component in repeat each components {
      contents.append(component)
    }
    return _JoinedPromptContent(contents: contents)
  }

  public static func buildExpression<P: CactusPromptRepresentable>(_ expression: P) -> P {
    expression
  }

  public static func buildLimitedAvailability<P: CactusPromptRepresentable>(_ expression: P) -> P {
    expression
  }

  public static func buildEither<P: CactusPromptRepresentable>(first component: P) -> P {
    component
  }

  public static func buildEither<P: CactusPromptRepresentable>(second component: P) -> P {
    component
  }
}

public struct _JoinedPromptContent: CactusPromptRepresentable {
  let contents: [any CactusPromptRepresentable]

  public var promptContent: CactusPromptContent {
    get throws {
      var prompt = CactusPromptContent()
      for content in self.contents {
        prompt.join(with: try content.promptContent)
      }
      return prompt
    }
  }
}
