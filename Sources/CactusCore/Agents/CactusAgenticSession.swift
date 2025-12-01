import Observation

// MARK: - CactusAgenticSession

public final class CactusAgenticSession<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromCactusResponse
> {
  public var isResponding: Bool {
    false
  }

  public var transcript: CactusTranscript {
    CactusTranscript()
  }

  public init(
    _ agent: sending some CactusAgent<Input, Output>,
    functions: [any CactusFunction] = [],
    @CactusPromptBuilder systemPrompt: () -> CactusPromptContent
  ) {

  }

  public init(
    _ agent: sending some CactusAgent<Input, Output>,
    functions: [any CactusFunction] = [],
    transcript: CactusTranscript
  ) {

  }
}

// MARK: - Observable

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension CactusAgenticSession: Observable {

}
