import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusTranscription tests` {
  @Test
  func `Empty String Response`() {
    let content = CactusTranscription.Content(response: "")
    expectNoDifference(content, .fullTranscript(""))
  }

  @Test
  func `No Timestamps Response`() {
    let responseText = "Hello world<|startoftranscript|>"
    let content = CactusTranscription.Content(response: responseText)

    expectNoDifference(content, .fullTranscript("Hello world"))
  }

  @Test
  func `Timestamps Response`() {
    let content = CactusTranscription.Content(
      response: """
        <|0.00|> How? The power of a god cannot be overcome.\
        <|3.14|> Zanzan, this is the providence of the world. Even gods are merely beings \
        restricted to the limited power determined by prophets.\
        <|6.56|> That power, although great, is not unlimited. \
        <|9.31|> That voice, Albrecht! How dare you!\
        <|startoftranscript|>
        """
    )
    expectNoDifference(
      content,
      .timestamps([
        CactusTranscription.Timestamp(
          seconds: 0,
          transcript: "How? The power of a god cannot be overcome."
        ),
        CactusTranscription.Timestamp(
          seconds: 3.14,
          transcript: """
            Zanzan, this is the providence of the world. Even gods are merely beings \
            restricted to the limited power determined by prophets.
            """
        ),
        CactusTranscription.Timestamp(
          seconds: 6.56,
          transcript: "That power, although great, is not unlimited. "
        ),
        CactusTranscription.Timestamp(
          seconds: 9.31,
          transcript: "That voice, Albrecht! How dare you!"
        )
      ])
    )
  }

  @Test
  func `Timestamps Response With Start End Markers`() {
    let content = CactusTranscription.Content(
      response:
        "<|0.02|> The power of a god cannot be overcome!<|2.94|><|3.14|> Zanza, this is the providence of the world.<|6.12|><|6.28|> Even gods are merely beings restricted to limited power determined by promise that power...<|12.76|><|13.10|> ...although great is not unlimited<|15.96|><|16.02|> That voice! Abyss!? How dare you disobey me?<|19.34|><|19.98|> I am Manada. I was here at beginning and will proclaim it's end<|25.16|><|25.30|> But that..that's impossible<|27.18|><|27.26|>"
    )
    expectNoDifference(
      content,
      .timestamps([
        CactusTranscription.Timestamp(
          seconds: 0.02,
          transcript: "The power of a god cannot be overcome!"
        ),
        .silence(seconds: 2.94),
        CactusTranscription.Timestamp(
          seconds: 3.14,
          transcript: "Zanza, this is the providence of the world."
        ),
        .silence(seconds: 6.12),
        CactusTranscription.Timestamp(
          seconds: 6.28,
          transcript:
            "Even gods are merely beings restricted to limited power determined by promise that power..."
        ),
        .silence(seconds: 12.76),
        CactusTranscription.Timestamp(
          seconds: 13.10,
          transcript: "...although great is not unlimited"
        ),
        .silence(seconds: 15.96),
        CactusTranscription.Timestamp(
          seconds: 16.02,
          transcript: "That voice! Abyss!? How dare you disobey me?"
        ),
        .silence(seconds: 19.34),
        CactusTranscription.Timestamp(
          seconds: 19.98,
          transcript: "I am Manada. I was here at beginning and will proclaim it's end"
        ),
        .silence(seconds: 25.16),
        CactusTranscription.Timestamp(
          seconds: 25.30,
          transcript: "But that..that's impossible"
        ),
        .silence(seconds: 27.18),
        .silence(seconds: 27.26)
      ])
    )
  }

  @Test
  func `Content response from fullTranscript`() {
    let content = CactusTranscription.Content.fullTranscript("Hello world")
    expectNoDifference(content.response, "Hello world")
  }

  @Test
  func `Content response from fullTranscript with complex text`() {
    let transcript = """
      How? The power of a god cannot be overcome. Zanzan, this is the providence of the world. \
      Even gods are merely beings restricted to the limited power determined by prophets. That \
      power, although great, is not unlimited. That voice, Albrecht! How dare you!
      """
    let content = CactusTranscription.Content.fullTranscript(transcript)
    expectNoDifference(content.response, transcript)
  }

  @Test
  func `Content response from timestamps`() {
    let timestamps = [
      CactusTranscription.Timestamp(seconds: 0, transcript: "Hello"),
      CactusTranscription.Timestamp(seconds: 1.5, transcript: "World")
    ]
    let content = CactusTranscription.Content.timestamps(timestamps)
    expectNoDifference(content.response, "<0>Hello<1.5>World")
  }

  @Test
  func `Content response from timestamps with complex example`() {
    let responseString = """
      <|0.00|> How? The power of a god cannot be overcome.\
      <|3.14|> Zanzan, this is the providence of the world. Even gods are merely beings \
      restricted to the limited power determined by prophets.\
      <|6.56|> That power, although great, is not unlimited. \
      <|9.31|> That voice, Albrecht! How dare you!\
      <|startoftranscript|>
      """
    let content = CactusTranscription.Content(response: responseString)
    expectNoDifference(
      content.response,
      "<0>How? The power of a god cannot be overcome.<3.14>Zanzan, this is the providence of the world. Even gods are merely beings restricted to the limited power determined by prophets.<6.56>That power, although great, is not unlimited. <9.31>That voice, Albrecht! How dare you!"
    )
  }

  @Test
  func `Content response from timestamps with silence markers`() {
    let responseString =
      "<|0.02|> The power of a god cannot be overcome!<|2.94|><|3.14|> Zanza, this is the providence of the world."
    let content = CactusTranscription.Content(response: responseString)
    expectNoDifference(
      content.response,
      "<0.02>The power of a god cannot be overcome!<2.94><3.14>Zanza, this is the providence of the world."
    )
  }
}

extension CactusTranscription.Timestamp {
  fileprivate static func silence(seconds: TimeInterval) -> Self {
    Self(seconds: seconds, transcript: "")
  }
}
