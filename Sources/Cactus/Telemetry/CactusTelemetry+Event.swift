import Foundation

// MARK: - Event

extension CactusTelemetry {
  public protocol Event {
    var name: String { get }
  }
}

// MARK: - ChatCompletionEvent

extension CactusTelemetry {
  public struct ChatCompletionEvent: Event, Sendable {
    public private(set) var name = "completion"
    public let chatCompletion: CactusLanguageModel.ChatCompletion
    public let configuration: CactusLanguageModel.Configuration

    public init(
      chatCompletion: CactusLanguageModel.ChatCompletion,
      configuration: CactusLanguageModel.Configuration
    ) {
      self.chatCompletion = chatCompletion
      self.configuration = configuration
    }
  }
}

// MARK: - EmbeddingsEvent

extension CactusTelemetry {
  public struct EmbeddingsEvent: Event, Sendable {
    public private(set) var name = "embedding"
    public let configuration: CactusLanguageModel.Configuration

    public init(configuration: CactusLanguageModel.Configuration) {
      self.configuration = configuration
    }
  }
}

// MARK: - LanguageModelInitEvent

extension CactusTelemetry {
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
