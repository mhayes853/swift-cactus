import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusTranscript tests` {
  @Test
  func `Empty Transcript`() {
    let transcript = CactusTranscript()
    expectNoDifference(transcript.isEmpty, true)
    expectNoDifference(transcript.count, 0)
  }

  @Test
  func `Append Element And Access By ID`() {
    var transcript = CactusTranscript()
    let id = CactusGenerationID()
    let message = CactusModel.ChatMessage.user("Hello")
    let element = CactusTranscript.Element(id: id, message: message)

    transcript.append(element)

    expectNoDifference(transcript.count, 1)
    expectNoDifference(transcript.isEmpty, false)
    expectNoDifference(transcript[id: id]?.message, message)
  }

  @Test
  func `Collection Conformance`() {
    var transcript = CactusTranscript()
    let id1 = CactusGenerationID()
    let id2 = CactusGenerationID()

    transcript.append(CactusTranscript.Element(id: id1, message: .user("First")))
    transcript.append(CactusTranscript.Element(id: id2, message: .user("Second")))

    expectNoDifference(transcript.startIndex, 0)
    expectNoDifference(transcript.endIndex, 2)
    expectNoDifference(transcript[0].message.content, "First")
    expectNoDifference(transcript[1].message.content, "Second")

    var contents = [String]()
    for element in transcript {
      contents.append(element.message.content)
    }
    expectNoDifference(contents, ["First", "Second"])
  }

  @Test
  func `Messages Property`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .system("You are helpful")))
    transcript.append(CactusTranscript.Element(message: .user("Hi")))
    transcript.append(CactusTranscript.Element(message: .assistant("Hello!")))

    let messages = transcript.messages
    expectNoDifference(messages, [.system("You are helpful"), .user("Hi"), .assistant("Hello!")])
  }

  @Test
  func `Filter By Role`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .system("System message")))
    transcript.append(CactusTranscript.Element(message: .user("User 1")))
    transcript.append(CactusTranscript.Element(message: .assistant("Assistant 1")))
    transcript.append(CactusTranscript.Element(message: .user("User 2")))
    transcript.append(CactusTranscript.Element(message: .assistant("Assistant 2")))

    let userTranscript = transcript.filter(byRole: .user)
    expectNoDifference(userTranscript.map(\.message.content), ["User 1", "User 2"])
  }

  @Test
  func `First And Last Message For Role`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .system("System")))
    transcript.append(CactusTranscript.Element(message: .user("User 1")))
    transcript.append(CactusTranscript.Element(message: .assistant("Assistant 1")))
    transcript.append(CactusTranscript.Element(message: .user("User 2")))

    expectNoDifference(transcript.firstMessage(forRole: .system)?.message.content, "System")
    expectNoDifference(transcript.firstMessage(forRole: .user)?.message.content, "User 1")
    expectNoDifference(transcript.lastMessage(forRole: .user)?.message.content, "User 2")
    expectNoDifference(transcript.firstMessage(forRole: .assistant)?.message.content, "Assistant 1")
    expectNoDifference(transcript.lastMessage(forRole: .assistant)?.message.content, "Assistant 1")
    expectNoDifference(transcript.firstMessage(forRole: "custom"), nil)
  }

  @Test
  func `Remove Element By ID`() {
    var transcript = CactusTranscript()
    let id1 = CactusGenerationID()
    let id2 = CactusGenerationID()
    let id3 = CactusGenerationID()

    transcript.append(CactusTranscript.Element(id: id1, message: .user("First")))
    transcript.append(CactusTranscript.Element(id: id2, message: .user("Second")))
    transcript.append(CactusTranscript.Element(id: id3, message: .user("Third")))

    let removed = transcript.removeElement(id: id2)

    expectNoDifference(removed?.message.content, "Second")
    expectNoDifference(transcript[id: id2], nil)
    expectNoDifference(transcript.map(\.message.content), ["First", "Third"])
  }

  @Test
  func `Remove Element At Index`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .user("First")))
    transcript.append(CactusTranscript.Element(message: .user("Second")))
    transcript.append(CactusTranscript.Element(message: .user("Third")))

    let removed = transcript.removeElement(at: 1)

    expectNoDifference(removed.message.content, "Second")
    expectNoDifference(transcript.map(\.message.content), ["First", "Third"])
  }

  @Test
  func `Remove All`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .user("First")))
    transcript.append(CactusTranscript.Element(message: .user("Second")))

    transcript.removeAll()

    expectNoDifference(transcript.isEmpty, true)
  }

  @Test
  func `Remove All Where`() throws {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .system("System")))
    transcript.append(CactusTranscript.Element(message: .user("User 1")))
    transcript.append(CactusTranscript.Element(message: .assistant("Assistant")))
    transcript.append(CactusTranscript.Element(message: .user("User 2")))

    transcript.removeAll { $0.message.role == .user }

    expectNoDifference(transcript.messages.map(\.role), [.system, .assistant])
  }

  @Test
  func `Append Contents Of`() {
    var transcript = CactusTranscript()
    let elements = [
      CactusTranscript.Element(message: .user("First")),
      CactusTranscript.Element(message: .user("Second"))
    ]

    transcript.append(contentsOf: elements)

    expectNoDifference(transcript.count, 2)
    expectNoDifference(transcript[0].message.content, "First")
    expectNoDifference(transcript[1].message.content, "Second")
  }

  @Test
  func `Insert Element At Beginning`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .user("Second")))

    transcript.insert(CactusTranscript.Element(message: .user("First")), at: 0)

    expectNoDifference(transcript.count, 2)
    expectNoDifference(transcript[0].message.content, "First")
    expectNoDifference(transcript[1].message.content, "Second")
  }

  @Test
  func `Insert Element At Middle`() {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .user("First")))
    transcript.append(CactusTranscript.Element(message: .user("Third")))

    transcript.insert(CactusTranscript.Element(message: .user("Second")), at: 1)

    expectNoDifference(transcript.count, 3)
    expectNoDifference(transcript[0].message.content, "First")
    expectNoDifference(transcript[1].message.content, "Second")
    expectNoDifference(transcript[2].message.content, "Third")
  }

  @Test
  func `Insert Element Updates ID Index`() {
    var transcript = CactusTranscript()
    let id1 = CactusGenerationID()
    let id2 = CactusGenerationID()
    transcript.append(CactusTranscript.Element(id: id1, message: .user("First")))
    transcript.append(CactusTranscript.Element(id: id2, message: .user("Third")))

    transcript.insert(CactusTranscript.Element(message: .user("Second")), at: 1)

    expectNoDifference(transcript[id: id1]?.message.content, "First")
    expectNoDifference(transcript[id: id2]?.message.content, "Third")
    expectNoDifference(transcript[0].id, id1)
    expectNoDifference(transcript[1].message.content, "Second")
    expectNoDifference(transcript[2].id, id2)
  }

  @Test
  func `Init With Elements`() {
    let elements = [
      CactusTranscript.Element(message: .system("System")),
      CactusTranscript.Element(message: .user("User"))
    ]

    let transcript = CactusTranscript(elements: elements)

    expectNoDifference(transcript.count, 2)
    expectNoDifference(transcript[0].message.role, .system)
    expectNoDifference(transcript[1].message.role, .user)
  }

  @Test
  func `Codable Round Trip`() throws {
    var transcript = CactusTranscript()
    transcript.append(CactusTranscript.Element(message: .system("You are helpful")))
    transcript.append(CactusTranscript.Element(message: .user("Hi")))
    transcript.append(CactusTranscript.Element(message: .assistant("Hello!")))

    let encoder = JSONEncoder()
    let data = try encoder.encode(transcript)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(CactusTranscript.self, from: data)

    expectNoDifference(decoded.count, 3)
    expectNoDifference(decoded.messages, transcript.messages)
    expectNoDifference(decoded[0].id, transcript[0].id)
  }

  @Test
  func `Modify Element At Index`() {
    var transcript = CactusTranscript()
    let id = CactusGenerationID()
    transcript.append(CactusTranscript.Element(id: id, message: .user("Hello")))

    transcript[0].message = CactusModel.ChatMessage.user("Hello, world!")

    expectNoDifference(transcript.count, 1)
    expectNoDifference(transcript[0].message.content, "Hello, world!")
    expectNoDifference(transcript[0].id, id)
    expectNoDifference(transcript[id: id]?.message.content, "Hello, world!")
  }

  @Test
  func `Replace Element At Index`() {
    var transcript = CactusTranscript()
    let oldID = CactusGenerationID()
    let newID = CactusGenerationID()
    transcript.append(CactusTranscript.Element(id: oldID, message: .user("First")))
    transcript.append(CactusTranscript.Element(message: .user("Second")))

    transcript[0] = CactusTranscript.Element(id: newID, message: .user("Replaced"))

    expectNoDifference(transcript.count, 2)
    expectNoDifference(transcript[0].message.content, "Replaced")
    expectNoDifference(transcript[0].id, newID)
    expectNoDifference(transcript[id: oldID], nil)
    expectNoDifference(transcript[id: newID]?.message.content, "Replaced")
  }

  @Test
  func `Reserve Capacity`() {
    var transcript = CactusTranscript()
    transcript.reserveCapacity(100)

    expectNoDifference(transcript.isEmpty, true)

    for i in 0..<50 {
      transcript.append(CactusTranscript.Element(message: .user("Message \(i)")))
    }

    expectNoDifference(transcript.count, 50)
  }

  #if os(macOS)
    @Test
    func `Duplicate ID Precondition Failure`() async {
      await #expect(processExitsWith: .failure) {
        let existingID = CactusGenerationID()
        var transcript = CactusTranscript()
        transcript.append(CactusTranscript.Element(id: existingID, message: .user("First")))
        transcript.append(CactusTranscript.Element(message: .user("Second")))
        transcript[1] = CactusTranscript.Element(id: existingID, message: .user("Duplicate"))
      }
    }
  #endif
}
