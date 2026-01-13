import Foundation

struct FFIErrorResponse: Decodable {
  let error: String
}

let ffiDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
    decoder.allowsJSON5 = true
  }
  return decoder
}()

let ffiEncoder: JSONEncoder = {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.withoutEscapingSlashes]
  return encoder
}()
