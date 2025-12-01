public struct CactusResponse: Hashable, Sendable, Identifiable {
  public let id: CactusGenerationID
  public let content: String

  public init(id: CactusGenerationID, content: String) {
    self.id = id
    self.content = content
  }
}
