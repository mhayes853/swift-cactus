import Cactus
import CustomDump
import Testing

@Suite
struct `CactusEnvironmentValues tests` {
  @Test
  func `Returns Default Value When No Value Set`() {
    let values = CactusEnvironmentValues()
    expectNoDifference(values.test, _defaultValue)
  }

  @Test
  func `Returns Newly Set Value`() {
    var values = CactusEnvironmentValues()
    values.test = _defaultValue + 100
    expectNoDifference(values.test, _defaultValue + 100)
  }

  @Test
  func `CustomStringConvertible`() {
    var values = CactusEnvironmentValues()
    expectNoDifference(values.description, "[]")

    values.test = _defaultValue + 200
    expectNoDifference(values.description, "[CactusEnvironmentValues.TestKey = \(values.test)]")

    values.test2 = "Vlov"
    let expected = Set([
      "[CactusEnvironmentValues.TestKey = \(values.test), CactusEnvironmentValues.Test2Key = Vlov]",
      "[CactusEnvironmentValues.Test2Key = Vlov, CactusEnvironmentValues.TestKey = \(values.test)]"
    ])
    expectNoDifference(expected.contains(values.description), true)
  }
}

private let _defaultValue = 100

extension CactusEnvironmentValues {
  fileprivate var test: Int {
    get { self[TestKey.self] }
    set { self[TestKey.self] = newValue }
  }

  private enum TestKey: Key {
    static let defaultValue = _defaultValue
  }

  fileprivate var test2: String {
    get { self[Test2Key.self] }
    set { self[Test2Key.self] = newValue }
  }

  private enum Test2Key: Key {
    static let defaultValue = "Blob"
  }
}
