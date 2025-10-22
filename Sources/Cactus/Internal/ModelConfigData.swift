import Foundation

struct ModelConfigData {
  private var items = [Substring: Substring]()

  init(rawData: Data) {
    let stringified = String(decoding: rawData, as: UTF8.self)
    for line in stringified.split(separator: "\n") {
      let line = line.trimmingCharacters(in: .whitespaces)
      guard !line.starts(with: "#") else { continue }
      let splits = line.split(separator: "=")
      guard splits.count == 2 else { continue }
      self.items[splits[0]] = splits[1]
    }
  }

  func string(forKey key: String) -> String? {
    self.items[Substring(key)].map { String($0) }
  }

  func integer(forKey key: String) -> Int? {
    self.string(forKey: key).flatMap { Int($0) }
  }

  func double(forKey key: String) -> Double? {
    self.string(forKey: key).flatMap { Double($0) }
  }

  func boolean(forKey key: String) -> Bool? {
    self.string(forKey: key).flatMap { Bool($0) }
  }
}
