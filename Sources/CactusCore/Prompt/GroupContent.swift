/// Groups prompt builder output into a single prompt representable value.
///
/// Grouping is useful when applying modifiers (such as ``CactusPromptRepresentable/separated(by:)``
/// or ``CactusPromptRepresentable/encoded(with:)``) to a specific subset of prompt content.
///
/// ```swift
/// let content = CactusPromptContent {
///   GroupContent {
///     "Name: Blob"
///     "Role: Assistant"
///   }
///   .separated(by: " | ")
/// }
///
/// let components = try content.messageComponents()
/// // components.text == "Name: Blob | Role: Assistant"
/// ```
public struct GroupContent<Content: CactusPromptRepresentable>: CactusPromptRepresentable {
  private let content: Content

  public var promptContent: CactusPromptContent {
    get throws {
      try self.content.promptContent
    }
  }

  /// Creates grouped prompt content from a prompt builder closure.
  ///
  /// - Parameter builder: A prompt builder closure.
  public init(@CactusPromptBuilder builder: () -> Content) {
    self.content = builder()
  }
}
