import Foundation

func temporaryModelDirectory() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent("tmp-model-\(UUID())")
}
