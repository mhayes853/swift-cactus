import Cactus
import CustomDump
import Testing

@Suite
struct `CactusPromptContent tests` {
  @Test
  func `Message Components For Basic String`() throws {
    let content = CactusPromptContent(text: "Hello world!")
    let components = try content.messageComponents()
    expectNoDifference(components.text, "Hello world!")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Message Components For Basic Image`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let content = CactusPromptContent(images: [imageURL])
    let components = try content.messageComponents()
    expectNoDifference(components.text, "")
    expectNoDifference(components.images, [imageURL])
  }

  @Test
  func `Join Image Content With String Content`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let content1 = CactusPromptContent(images: [imageURL])
    let content2 = CactusPromptContent(text: "Hello world!")
    let components = try content1.joined(with: content2).messageComponents()
    expectNoDifference(components.text, "Hello world!")
    expectNoDifference(components.images, [imageURL])
  }

  @Test
  func `Join String Content With Custom Separator`() throws {
    let content1 = CactusPromptContent(text: "Hello")
    let content2 = CactusPromptContent(text: "world!")
    let components = try content1.joined(with: content2, separator: " ").messageComponents()
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
      .messageComponents()
    expectNoDifference(components.text, "Hello world!, this is cool")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Prompt Builder Joins Content With New Lines`() throws {
    let imageURL = temporaryModelDirectory().appendingPathComponent("image.png")
    let imageURL2 = temporaryModelDirectory().appendingPathComponent("image2.png")
    let content = CactusPromptContent {
      "Hello world"
      CactusPromptContent(images: [imageURL])
      "This is cool"
      CactusPromptContent(images: [imageURL2])
    }
    let components = try content.messageComponents()
    expectNoDifference(components.text, "Hello world\nThis is cool")
    expectNoDifference(components.images, [imageURL, imageURL2])
  }

  @Test
  func `Prompt Builder Joins Content With Ohter Prompt Representables`() throws {
    struct Representable: CactusPromptRepresentable {
      let imageURL2 = temporaryModelDirectory().appendingPathComponent("image2.png")

      var promptContent: CactusPromptContent {
        CactusPromptContent {
          "This is cool"
          CactusPromptContent(images: [self.imageURL2])
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

    let components = try content.messageComponents()
    expectNoDifference(components.text, "Hello world\nThis is cool")
    expectNoDifference(components.images, [imageURL, representable.imageURL2])
  }

  @Test
  func `Prompt Builder Throws Error When Representation Throws Error`() throws {
    struct SomeError: Error {}
    struct Representable: CactusPromptRepresentable {
      var promptContent: CactusPromptContent {
        get throws { throw SomeError() }
      }
    }

    let content = CactusPromptContent(Representable())
    #expect(throws: SomeError.self) { try content.messageComponents() }
  }
}
