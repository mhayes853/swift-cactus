extension CactusLanguageModel {
  var defaultChatCompletionOptions: CactusLanguageModel.InferenceOptions {
    CactusLanguageModel.InferenceOptions(
      modelType: self.configurationFile.modelType ?? .qwen
    )
  }

  var defaultTranscriptionOptions: CactusLanguageModel.InferenceOptions {
    CactusLanguageModel.InferenceOptions(
      modelType: self.configurationFile.modelType ?? .whisper
    )
  }
}
