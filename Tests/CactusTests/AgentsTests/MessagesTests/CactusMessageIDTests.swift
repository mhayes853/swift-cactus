import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusMessageID tests` {
  @Test
  func `Encode Then Decode`() throws {
    let id = CactusMessageID()
    let data = try JSONEncoder().encode(id)
    let decodedId = try JSONDecoder().decode(CactusMessageID.self, from: data)
    expectNoDifference(id, decodedId)
  }

  @Test
  func `Encodes To Single Value UUID`() throws {
    let id = CactusMessageID()
    let data = try JSONEncoder().encode(id)
    #expect(throws: Never.self) {
      try JSONDecoder().decode(UUID.self, from: data)
    }
  }
}
