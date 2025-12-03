import Cactus
import CustomDump
import Testing

@Suite
struct `Qwen3Response tests` {
  @Test
  func `Loads Response From Plain String`() throws {
    let id = CactusGenerationID()
    let response = Qwen3Response<String>(
      cactusResponse: CactusResponse(id: id, content: "Hello world")
    )
    expectNoDifference(
      response,
      Qwen3Response(id: id, thinkingContent: nil, response: "Hello world")
    )
  }

  @Test
  func `Loads Custom Response Type From Plain String`() throws {
    let id = CactusGenerationID()
    let response = Qwen3Response<TestResponse>(
      cactusResponse: CactusResponse(id: id, content: "blob")
    )
    expectNoDifference(
      response,
      Qwen3Response(id: id, thinkingContent: nil, response: TestResponse(text: "blob"))
    )
  }

  @Test
  func `Loads Custom Response Type From String With Thinking Content`() throws {
    let id = CactusGenerationID()
    let response = Qwen3Response<TestResponse>(
      cactusResponse: CactusResponse(id: id, content: sampleThinkingResponse)
    )
    expectNoDifference(
      response,
      Qwen3Response(
        id: id,
        thinkingContent: """
          Okay, the user is asking about the meaning of life. First, I need to acknowledge that this \
          is a complex and philosophical question. As a philosopher, I should approach it with curiosity and openness.

          I should start by explaining that meaning of life isn't something we can find in one's own \
          mind or through experience alone. It's subjective and varies from person to person \
          depending on personal values and experiences.

          Next, consider different perspectives: some might seek purpose through work or \
          relationships; others might value spiritual fulfillment or personal growth. It's important \
          to highlight that there are many possible paths toward meaningful living.

          Also mention that exploring this topic requires reflection on our beliefs, values, goals in life choices we make today.
          """,
        response: TestResponse(
          text: """
            The meaning of life is inherently subjective and deeply rooted in individual experiences. \
            As a philosopher, I would emphasize the following key points:

            1. **Subjectivity**: The pursuit of meaning is not universal; it varies widely based on \
            cultural context, personal aspirations (e.g.,
            """
        )
      )
    )
  }

  @Test
  func `Loads Custom Response Type From String With Partial Thinking Content`() throws {
    let id = CactusGenerationID()
    let response = Qwen3Response<TestResponse>(
      cactusResponse: CactusResponse(id: id, content: samplePartialThinkingResponse)
    )
    expectNoDifference(
      response,
      Qwen3Response(
        id: id,
        thinkingContent:
          "Okay, the user is asking about the meaning of life. First, I need to acknowledge that this",
        response: TestResponse(
          text: ""
        )
      )
    )
  }

  @Test
  func `Formats Prompt Content Without Thinking Content`() throws {
    let id = CactusGenerationID()
    let response = Qwen3Response<String>(
      cactusResponse: CactusResponse(id: id, content: "This is cool")
    )
    let components = try response.defaultMessageComponents()
    expectNoDifference(components.text, "This is cool")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Formats Prompt Content With Thinking Content`() throws {
    let id = CactusGenerationID()
    let response = Qwen3Response<String>(
      cactusResponse: CactusResponse(id: id, content: sampleThinkingResponse)
    )
    let components = try response.defaultMessageComponents()
    expectNoDifference(components.text, sampleThinkingResponse)
    expectNoDifference(components.images, [])
  }
}

private struct TestResponse: Hashable, Sendable, ConvertibleFromCactusResponse {
  let text: String

  init(text: String) {
    self.text = text
  }

  var promptContent: CactusPromptContent {
    CactusPromptContent(text: self.text)
  }

  init(cactusResponse: CactusResponse) {
    self.text = cactusResponse.content
  }
}

private let sampleThinkingResponse = """
  <think>
  Okay, the user is asking about the meaning of life. First, I need to acknowledge that this \
  is a complex and philosophical question. As a philosopher, I should approach it with curiosity and openness.

  I should start by explaining that meaning of life isn't something we can find in one's own \
  mind or through experience alone. It's subjective and varies from person to person \
  depending on personal values and experiences.

  Next, consider different perspectives: some might seek purpose through work or \
  relationships; others might value spiritual fulfillment or personal growth. It's important \
  to highlight that there are many possible paths toward meaningful living.

  Also mention that exploring this topic requires reflection on our beliefs, values, goals in life choices we make today.
  </think>

  The meaning of life is inherently subjective and deeply rooted in individual experiences. \
  As a philosopher, I would emphasize the following key points:

  1. **Subjectivity**: The pursuit of meaning is not universal; it varies widely based on \
  cultural context, personal aspirations (e.g.,
  """

private let samplePartialThinkingResponse = """
  <think>
  Okay, the user is asking about the meaning of life. First, I need to acknowledge that this
  """
