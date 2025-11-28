public final actor CactusAgenticSession<
  Input: CactusPromptRepresentable,
  Output: ConvertibleFromJSONValue
> {

  public init(
    _ agent: sending some CactusAgent<Input, Output>,
    systemPrompt: some CactusPromptRepresentable
  ) {

  }

  public init(
    _ agent: sending some CactusAgent<Input, Output>,
    transcript: CactusTranscript
  ) {

  }
}
