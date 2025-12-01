import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusGenerationID tests` {
  @Test
  func `Encode Then Decode`() throws {
    let id = CactusGenerationID()
    let data = try JSONEncoder().encode(id)
    let decodedId = try JSONDecoder().decode(CactusGenerationID.self, from: data)
    expectNoDifference(id, decodedId)
  }

  @Test
  func `Encodes To Single Value UUID`() throws {
    let id = CactusGenerationID()
    let data = try JSONEncoder().encode(id)
    #expect(throws: Never.self) {
      try JSONDecoder().decode(UUID.self, from: data)
    }
  }
}
