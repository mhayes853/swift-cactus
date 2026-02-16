import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusPromptContent tests` {
  @Test
  func `Message Components For Basic String`() throws {
    let content = CactusPromptContent(text: "Hello world!")
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello world!")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Message Components For Basic Image`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let content = CactusPromptContent(images: [imageURL])
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "")
    expectNoDifference(components.images, [imageURL])
  }

  @Test
  func `Join Image Content With String Content`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let content1 = CactusPromptContent(images: [imageURL])
    let content2 = CactusPromptContent(text: "Hello world!")
    let components = try content1.joined(with: content2).defaultMessageComponents()
    expectNoDifference(components.text, "Hello world!")
    expectNoDifference(components.images, [imageURL])
  }

  @Test
  func `Join String Content With Custom Separator`() throws {
    let content1 = CactusPromptContent(text: "Hello")
    let content2 = CactusPromptContent(text: "world!")
    let components = try content1.joined(with: content2, separator: " ").defaultMessageComponents()
    expectNoDifference(components.text, "Hello world!")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Join Multiple String Content With Custom Separators`() throws {
    let content1 = CactusPromptContent(text: "Hello")
    let content2 = CactusPromptContent(text: "world!")
    let content3 = CactusPromptContent(text: "this is cool")
    let components = try content1.joined(with: content2, separator: " ")
      .joined(with: content3, separator: ", ")
      .defaultMessageComponents()
    expectNoDifference(components.text, "Hello world!, this is cool")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt Builder Joins Text Content With New Lines`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let imageURL2 = temporaryModelDirectory().appendingPathComponent("image2.png")
    let content = CactusPromptContent {
      "Hello world"
      CactusPromptContent(images: [imageURL])
      CactusPromptContent(images: [imageURL2])
      "This is cool"
    }
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello world\nThis is cool")
    expectNoDifference(components.images, [imageURL, imageURL2])
  }

  @Test
  func `Prompt Builder Joins Content With Other Prompt Representables`() throws {
    struct Representable: CactusPromptRepresentable {
      let imageURL2 = temporaryModelDirectory().appendingPathComponent("image2.png")

      var promptContent: CactusPromptContent {
        get throws {
          CactusPromptContent {
            "This is cool"
            CactusPromptContent(images: [self.imageURL2])
          }
        }
      }
    }

    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let representable = Representable()
    let content = CactusPromptContent {
      "Hello world"
      CactusPromptContent(images: [imageURL])
      representable
    }

    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello world\nThis is cool")
    expectNoDifference(components.images, [imageURL, representable.imageURL2])
  }

  @Test
  func `Prompt Builder Throws Error When Representation Throws Error`() throws {
    struct SomeError: Error {}

    struct Representable: CactusPromptRepresentable {
      var promptContent: CactusPromptContent {
        get throws {
          throw SomeError()
        }
      }
    }

    let content = CactusPromptContent(Representable())
    #expect(throws: SomeError.self) { try content.defaultMessageComponents() }
  }

  @Test
  func `Prompt With Custom Encoder`() throws {
    struct CustomEncoder: TopLevelEncoder {
      func encode(_ value: some Encodable) throws -> Data {
        Data("Hello blob!".utf8)
      }
    }

    struct MyType: Codable, CactusPromptRepresentable {
      let a: Int
      let b: String
    }

    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = .sortedKeys

    let content = CactusPromptContent {
      MyType(a: 1, b: "hello")
        .encoded(with: CustomEncoder())
      MyType(a: 1, b: "hello")
        .encoded(with: jsonEncoder)
    }

    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello blob!\n{\"a\":1,\"b\":\"hello\"}")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt With Custom Grouped Encoder`() throws {
    struct CustomEncoder: TopLevelEncoder {
      func encode(_ value: some Encodable) throws -> Data {
        Data("Hello blob!".utf8)
      }
    }

    struct MyType: Codable, CactusPromptRepresentable {
      let a: Int
      let b: String
    }

    let content = CactusPromptContent {
      GroupContent {
        MyType(a: 1, b: "hello")
        MyType(a: 1, b: "hello")
      }
      .encoded(with: CustomEncoder())
    }
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello blob!\nHello blob!")
    expectNoDifference(components.images, [])
  }

  @Test(arguments: [(true, 0), (false, 1)])
  func `Prompt With Conditional Content`(isTrue: Bool, expected: Int) throws {
    let values = ["first", "second"]
    let content = CactusPromptContent {
      if isTrue {
        values[0]
      } else {
        values[1]
      }
    }
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, values[expected])
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt With Optional Content`() throws {
    let value: String? = nil
    let value2: String? = "hello"
    let content = CactusPromptContent {
      value
      value2
    }
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "hello")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt With Custom Separator`() throws {
    let content = CactusPromptContent {
      GroupContent {
        "Hello"
        "World"
      }
      .separated(by: " ")
    }
    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello World")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Think Mode Modifier Prepends Think Command`() throws {
    let content = try CactusPromptContent {
      "Hello world"
    }
    .thinkMode(.think)
    .promptContent

    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "/think\nHello world")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Think Mode Modifier Prepends No Think Command`() throws {
    let content = try CactusPromptContent {
      "Hello world"
    }
    .thinkMode(.noThink)
    .promptContent

    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "/no_think\nHello world")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Separated Content Handles Text Around Image`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let content = CactusPromptContent {
      "Hello"
      CactusPromptContent(images: [imageURL])
      "World"
    }
    .separated(by: ", ")

    let components = try content.defaultMessageComponents()
    expectNoDifference(components.text, "Hello, World")
    expectNoDifference(components.images, [imageURL])
  }
}

extension CactusPromptRepresentable {
  fileprivate func defaultMessageComponents() throws -> CactusPromptContent.MessageComponents {
    try self.promptContent.messageComponents()
  }
}
