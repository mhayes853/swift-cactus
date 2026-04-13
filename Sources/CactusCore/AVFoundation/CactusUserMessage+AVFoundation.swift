#if canImport(AVFoundation)
  import AVFoundation

  // MARK: - CactusUserMessage + AVFoundation

  extension CactusUserMessage {
    /// Creates a user message with an audio buffer from an `AVAudioPCMBuffer`.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to include with this message.
    ///   - content: The prompt content for this user message.
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: Sampling temperature.
    ///   - topP: Nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - stopSequences: Phrases that stop generation when emitted.
    ///   - forceFunctions: Whether tool calls are forced when tools are provided.
    ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
    ///   - includeStopSequences: Whether stop sequences are kept in final output.
    ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
    ///   - enableThinkingIfSupported: Whether to enable thinking for models that support it.
    ///   - maxBufferSize: The maximum buffer size used to store the completion.
    ///   - cloudHandoff: Built-in cloud-handoff settings for this request.
    public init(
      pcmBuffer: AVAudioPCMBuffer,
      content: CactusPromptContent,
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = CactusModel.Completion.Options.defaultStopSequences,
      forceFunctions: Bool = false,
      toolRagTopK: Int = 2,
      includeStopSequences: Bool = false,
      isTelemetryEnabled: Bool = false,
      enableThinkingIfSupported: Bool = true,
      maxBufferSize: Int? = nil,
      cloudHandoff: CloudHandoff? = CloudHandoff()
    ) throws {
      self.init(
        content: content,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        stopSequences: stopSequences,
        forceFunctions: forceFunctions,
        toolRagTopK: toolRagTopK,
        includeStopSequences: includeStopSequences,
        isTelemetryEnabled: isTelemetryEnabled,
        enableThinkingIfSupported: enableThinkingIfSupported,
        maxBufferSize: maxBufferSize,
        cloudHandoff: cloudHandoff,
        pcmBuffer: try pcmBuffer.cactusPCMBytes()
      )
    }

    /// Creates a user message with an audio buffer from an `AVAudioPCMBuffer`.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to include with this message.
    ///   - content: The prompt content for this user message.
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: Sampling temperature.
    ///   - topP: Nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - stopSequences: Phrases that stop generation when emitted.
    ///   - forceFunctions: Whether tool calls are forced when tools are provided.
    ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
    ///   - includeStopSequences: Whether stop sequences are kept in final output.
    ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
    ///   - enableThinkingIfSupported: Whether to enable thinking for models that support it.
    ///   - maxBufferSize: The maximum buffer size used to store the completion.
    ///   - cloudHandoff: Built-in cloud-handoff settings for this request.
    public init(
      pcmBuffer: AVAudioPCMBuffer,
      _ content: some CactusPromptRepresentable,
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = CactusModel.Completion.Options.defaultStopSequences,
      forceFunctions: Bool = false,
      toolRagTopK: Int = 2,
      includeStopSequences: Bool = false,
      isTelemetryEnabled: Bool = false,
      enableThinkingIfSupported: Bool = true,
      maxBufferSize: Int? = nil,
      cloudHandoff: CloudHandoff? = CloudHandoff()
    ) throws {
      self.init(
        content,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        stopSequences: stopSequences,
        forceFunctions: forceFunctions,
        toolRagTopK: toolRagTopK,
        includeStopSequences: includeStopSequences,
        isTelemetryEnabled: isTelemetryEnabled,
        enableThinkingIfSupported: enableThinkingIfSupported,
        maxBufferSize: maxBufferSize,
        cloudHandoff: cloudHandoff,
        pcmBuffer: try pcmBuffer.cactusPCMBytes()
      )
    }

    /// Creates a user message with an audio buffer from an `AVAudioPCMBuffer`.
    ///
    /// - Parameters:
    ///   - buffer: The PCM buffer to include with this message.
    ///   - maxTokens: The maximum number of tokens for the completion.
    ///   - temperature: Sampling temperature.
    ///   - topP: Nucleus sampling probability.
    ///   - topK: The k most probable options to limit the next token to.
    ///   - stopSequences: Phrases that stop generation when emitted.
    ///   - forceFunctions: Whether tool calls are forced when tools are provided.
    ///   - toolRagTopK: Number of top tools to keep after tool-RAG selection.
    ///   - includeStopSequences: Whether stop sequences are kept in final output.
    ///   - isTelemetryEnabled: Whether telemetry is enabled for this request.
    ///   - enableThinkingIfSupported: Whether to enable thinking for models that support it.
    ///   - maxBufferSize: The maximum buffer size used to store the completion.
    ///   - cloudHandoff: Built-in cloud-handoff settings for this request.
    ///   - content: The prompt content for this user message.
    public init(
      pcmBuffer: AVAudioPCMBuffer,
      maxTokens: Int = 512,
      temperature: Float = 0.6,
      topP: Float = 0.95,
      topK: Int = 20,
      stopSequences: [String] = CactusModel.Completion.Options.defaultStopSequences,
      forceFunctions: Bool = false,
      toolRagTopK: Int = 2,
      includeStopSequences: Bool = false,
      isTelemetryEnabled: Bool = false,
      enableThinkingIfSupported: Bool = true,
      maxBufferSize: Int? = nil,
      cloudHandoff: CloudHandoff? = CloudHandoff(),
      @CactusPromptBuilder content: @Sendable () -> some CactusPromptRepresentable
    ) throws {
      self.init(
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        stopSequences: stopSequences,
        forceFunctions: forceFunctions,
        toolRagTopK: toolRagTopK,
        includeStopSequences: includeStopSequences,
        isTelemetryEnabled: isTelemetryEnabled,
        enableThinkingIfSupported: enableThinkingIfSupported,
        maxBufferSize: maxBufferSize,
        cloudHandoff: cloudHandoff,
        pcmBuffer: try pcmBuffer.cactusPCMBytes(),
        content: content
      )
    }
  }
#endif
