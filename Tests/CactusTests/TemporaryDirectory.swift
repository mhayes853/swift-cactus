import Foundation

func temporaryDirectory() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent("tmp-model-\(UUID())")
}
