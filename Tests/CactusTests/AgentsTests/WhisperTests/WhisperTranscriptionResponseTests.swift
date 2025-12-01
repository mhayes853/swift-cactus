import Cactus
import CustomDump
import Testing

@Suite
struct `WhisperTranscriptionResponse tests` {
  @Test
  func `Empty String Response`() {
    let response = WhisperTranscriptionResponse(
      cactusResponse: CactusResponse(id: CactusGenerationID(), content: "")
    )
    expectNoDifference(response, .fullTranscript(""))
  }

  @Test
  func `No Timestamps Response`() {
    let response = WhisperTranscriptionResponse(
      cactusResponse: CactusResponse(
        id: CactusGenerationID(),
        content: """
           How? The power of a god cannot be overcome. Zanzan, this is the providence of the world. \
          Even gods are merely beings restricted to the limited power determined by prophets. That \
          power, although great, is not unlimited. That voice, Albrecht! How dare you!\
          <|startoftranscript|>
          """
      )
    )

    let transcript = """
       How? The power of a god cannot be overcome. Zanzan, this is the providence of the world. \
      Even gods are merely beings restricted to the limited power determined by prophets. That \
      power, although great, is not unlimited. That voice, Albrecht! How dare you!
      """
    expectNoDifference(response, .fullTranscript(transcript))
  }

  @Test
  func `Timestamps Response`() {
    let response = WhisperTranscriptionResponse(
      cactusResponse: CactusResponse(
        id: CactusGenerationID(),
        content: """
          <|0.00|> How? The power of a god cannot be overcome.\
          <|3.14|> Zanzan, this is the providence of the world. Even gods are merely beings \
          restricted to the limited power determined by prophets.\
          <|6.56|> That power, although great, is not unlimited. \
          <|9.31|> That voice, Albrecht! How dare you!\
          <|startoftranscript|>
          """
      )
    )
    expectNoDifference(
      response,
      .timestamps([
        WhisperTranscriptionResponse.Timestamp(
          seconds: 0,
          transcript: " How? The power of a god cannot be overcome."
        ),
        WhisperTranscriptionResponse.Timestamp(
          seconds: 3.14,
          transcript: """
             Zanzan, this is the providence of the world. Even gods are merely beings \
            restricted to the limited power determined by prophets.
            """
        ),
        WhisperTranscriptionResponse.Timestamp(
          seconds: 6.56,
          transcript: " That power, although great, is not unlimited. "
        ),
        WhisperTranscriptionResponse.Timestamp(
          seconds: 9.31,
          transcript: " That voice, Albrecht! How dare you!"
        )
      ])
    )
  }
}
