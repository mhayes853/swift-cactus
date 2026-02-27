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

func bufferToData(_ buffer: UnsafePointer<CChar>, maxLength: Int) -> Data {
  let length = strnlen(buffer, maxLength)
  return buffer.withMemoryRebound(to: UInt8.self, capacity: length) { pointer in
    Data(bytes: pointer, count: length)
  }
}

func withFFIBuffer(
  bufferSize: Int = 8192,
  _ ffiCall: (UnsafeMutablePointer<CChar>, Int) throws -> Int32
) throws -> (result: Int32, responseData: Data) {
  let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
  defer { buffer.deallocate() }

  let result = try ffiCall(buffer, bufferSize * MemoryLayout<CChar>.stride)
  let responseData = bufferToData(buffer, maxLength: bufferSize)

  return (result, responseData)
}
