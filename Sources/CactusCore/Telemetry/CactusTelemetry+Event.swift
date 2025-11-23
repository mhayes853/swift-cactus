import Foundation

// MARK: - Event

extension CactusTelemetry {
  /// A telemetry event.
  public protocol Event {
    /// The name of the event.
    var name: String { get }
  }
}

// MARK: - ChatCompletionEvent

extension CactusTelemetry {
  /// A telemetry event for a chat completion.
  public struct LanguageModelCompletionEvent: Event, Sendable {
    public private(set) var name = "completion"
    public let chatCompletion: CactusLanguageModel.ChatCompletion
    public let options: CactusLanguageModel.ChatCompletion.Options
    public let configuration: CactusLanguageModel.Configuration

    public init(
      chatCompletion: CactusLanguageModel.ChatCompletion,
      options: CactusLanguageModel.ChatCompletion.Options,
      configuration: CactusLanguageModel.Configuration
    ) {
      self.chatCompletion = chatCompletion
      self.options = options
      self.configuration = configuration
    }
  }
}

// MARK: - EmbeddingsEvent

extension CactusTelemetry {
  /// A telemetry event for generating embeddings.
  public struct LanguageModelEmbeddingsEvent: Event, Sendable {
    public private(set) var name = "embedding"
    public let configuration: CactusLanguageModel.Configuration

    public init(configuration: CactusLanguageModel.Configuration) {
      self.configuration = configuration
    }
  }
}

// MARK: - LanguageModelInitEvent

extension CactusTelemetry {
  /// A telemetry event when initializing a ``CactusLanguageModel``.
  public struct LanguageModelInitEvent: Event, Sendable {
    public private(set) var name = "init"
    public let configuration: CactusLanguageModel.Configuration

    public init(configuration: CactusLanguageModel.Configuration) {
      self.configuration = configuration
    }
  }
}

// MARK: - LanguageModelErrorEvent

extension CactusTelemetry {
  /// A telemtry event for when a ``CactusLanguageModel`` fails to perform an operation.
  public struct LanguageModelErrorEvent: Event, Sendable {
    public let name: String
    public let message: String
    public let configuration: CactusLanguageModel.Configuration

    public init(name: String, message: String, configuration: CactusLanguageModel.Configuration) {
      self.name = name
      self.message = message
      self.configuration = configuration
    }
  }
}
