public struct Qwen3Response<
  Base: ConvertibleFromCactusResponse
>: ConvertibleFromCactusResponse {
  public let thinkingContent: String?
  public let response: Base

  public init(cactusResponse: CactusResponse) throws(Base.ConversionFailure) {
    let matches = thinkingContentRegex.matchGroups(from: cactusResponse.content)
    if matches.isEmpty {
      let thinkingPrefix = "<think>\n"
      let thinkingContent =
        cactusResponse.content.starts(with: thinkingPrefix)
        ? String(cactusResponse.content.dropFirst(thinkingPrefix.count))
        : nil
      self.thinkingContent = thinkingContent
      self.response = try Base(
        cactusResponse: CactusResponse(
          id: cactusResponse.id,
          content: thinkingContent != nil ? "" : cactusResponse.content
        )
      )
    } else {
      self.thinkingContent = String(matches[0])
      let baseResponse = matches.count > 1 ? matches[1] : ""
      self.response = try Base(
        cactusResponse: CactusResponse(id: cactusResponse.id, content: String(baseResponse))
      )
    }
  }

  public init(thinkingContent: String? = nil, response: Base) {
    self.thinkingContent = thinkingContent
    self.response = response
  }
}

private let thinkingContentRegex = try! RegularExpression(
  "<think>\n([\\s\\S]*?)\n<\\/think>\n\n([\\s\\S]*)"
)

extension Qwen3Response: Sendable where Base: Sendable {}
extension Qwen3Response: Equatable where Base: Equatable {}
extension Qwen3Response: Hashable where Base: Hashable {}

extension Qwen3Response: CactusPromptRepresentable where Base: CactusPromptRepresentable {
  public var promptContent: CactusPromptContent {
    get throws(Base.PromptContentFailure) {
      let baseContent = try self.response.promptContent
      return CactusPromptContent {
        GroupContent {
          if let thinkingContent {
            "<think>\n\(thinkingContent)\n</think>"
          }
          baseContent
        }
        .separated(by: "\n\n")
      }
    }
  }
}
