// MARK: - CactusPromptBuilder

@resultBuilder
public struct CactusPromptBuilder {
  public static func buildBlock<each P: CactusPromptRepresentable>(
    _ components: repeat each P
  ) -> _JoinedContent {
    var contents = [any CactusPromptRepresentable]()
    for component in repeat each components {
      contents.append(component)
    }
    return _JoinedContent(contents: contents)
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

  public static func buildOptional<P: CactusPromptRepresentable>(
    _ component: P?
  ) -> _OptionalContent<P> {
    _OptionalContent(content: component)
  }

  public static func buildArray(
    _ components: [some CactusPromptRepresentable]
  ) -> _JoinedContent {
    _JoinedContent(contents: components)
  }
}

// MARK: - Helpers

public struct _JoinedContent: CactusPromptRepresentable {
  let contents: [any CactusPromptRepresentable]

  public func promptContent(in environment: CactusEnvironmentValues) throws -> CactusPromptContent {
    var prompt = CactusPromptContent()
    for content in self.contents {
      prompt.join(
        with: try content.promptContent(in: environment),
        separator: environment.promptSeparator
      )
    }
    return prompt
  }
}

public struct _OptionalContent<
  Content: CactusPromptRepresentable
>: CactusPromptRepresentable {
  let content: Content?

  public func promptContent(
    in environment: CactusEnvironmentValues
  ) throws(Content.PromptContentFailure) -> CactusPromptContent {
    try self.content?.promptContent(in: environment) ?? CactusPromptContent()
  }
}
