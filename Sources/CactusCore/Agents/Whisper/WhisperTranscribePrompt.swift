import Foundation

public struct WhisperTranscribePrompt: Hashable, Sendable, CactusPromptRepresentable {
  public let language: WhisperLanguage
  public let includeTimestamps: Bool
  public let audioURL: URL

  public var promptContent: CactusPromptContent {
    CactusPromptContent {
      GroupContent {
        "<|startoftranscript|>"
        self.language
        "<|transcribe|>"
        if !self.includeTimestamps {
          "<|notimestamps|>"
        }
      }
      .separated(by: "")
    }
  }

  public init(language: WhisperLanguage, includeTimestamps: Bool, audioURL: URL) {
    self.language = language
    self.includeTimestamps = includeTimestamps
    self.audioURL = audioURL
  }
}
