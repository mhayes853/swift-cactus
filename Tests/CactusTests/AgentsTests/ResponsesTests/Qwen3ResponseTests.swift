import Cactus
import CustomDump
import Testing

@Suite
struct `Qwen3Response tests` {
  @Test
  func `Loads Response From Plain String`() throws {
    let response = Qwen3Response<String>(cactusResponse: "Hello world")
    expectNoDifference(response, Qwen3Response(thinkingContent: nil, response: "Hello world"))
  }

  @Test
  func `Loads Custom Response Type From Plain String`() throws {
    let response = Qwen3Response<TestResponse>(cactusResponse: "blob")
    expectNoDifference(
      response,
      Qwen3Response(thinkingContent: nil, response: TestResponse(text: "blob"))
    )
  }

  @Test
  func `Loads Custom Response Type From String With Thinking Content`() throws {
    let response = Qwen3Response<TestResponse>(cactusResponse: sampleThinkingResponse)
    expectNoDifference(
      response,
      Qwen3Response(
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
  func `Formats Prompt Content Without Thinking Content`() throws {
    let response = Qwen3Response<String>(cactusResponse: "This is cool")
    let components = try response.promptContent.messageComponents()
    expectNoDifference(components.text, "This is cool")
    expectNoDifference(components.images, [])
  }

  @Test
  func `Formats Prompt Content With Thinking Content`() throws {
    let response = Qwen3Response<String>(cactusResponse: sampleThinkingResponse)
    let components = try response.promptContent.messageComponents()
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

  init(cactusResponse: String) {
    self.text = cactusResponse
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
