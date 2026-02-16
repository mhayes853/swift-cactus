import Foundation

enum _CactusPromptContext {
  @TaskLocal
  static var separator = "\n"

  @TaskLocal
  static var encoder: AnyTopLevelEncoder<Data> = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.withoutEscapingSlashes]
    return AnyTopLevelEncoder(encoder)
  }()
}
