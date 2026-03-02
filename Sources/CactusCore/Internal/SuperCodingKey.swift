struct _SuperCodingKey: CodingKey {
  var stringValue: String { "super" }
  var intValue: Int? { nil }

  init?(stringValue: String) { return nil }
  init?(intValue: Int) { return nil }
  init() {}
}
