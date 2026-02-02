import CXXCactusShims
import Cactus
import CustomDump
import Foundation
import IssueReporting
import SnapshotTesting
import Testing
import XCTest

@Suite
struct `CactusLanguageModel tests` {
  @Test
  func `Throws Buffer Too Small Error When Buffer Size Zero`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 0)
    }
  }

  @Test
  func `Attempt To Create Model From Non-Existent URL, Throws Error`() async throws {
    let error = #expect(throws: CactusLanguageModel.ModelCreationError.self) {
      try CactusLanguageModel(from: temporaryModelDirectory())
    }
    expectNoDifference(error?.message.starts(with: "Failed to create model"), true)
  }

  @Test
  func `Successfully Creates Model From Downloaded Model`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    #expect(throws: Never.self) {
      try CactusLanguageModel(from: modelURL)
    }
  }

  @Test(.serialized, arguments: modelRequests)
  func `Generates Embeddings`(request: CactusLanguageModel.PlatformDownloadRequest) async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: request)
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.embeddings(for: "This is some text.")

    assertSnapshot(of: Embedding(slug: request.slug, vector: embeddings), as: .json)
  }

  @Test
  func `Throws Buffer Too Small Error When Buffer Size Too Small`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 20)
    }
  }

  @Test
  func `Tokenizes Text And Snapshots Output`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    let tokens = try model.tokenize(text: "Tokenize this text.")

    expectNoDifference(tokens.isEmpty, false)
    assertSnapshot(of: tokens, as: .json)
  }

  @Test
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  func `Tokenizes Text Into MutableSpan Buffer`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    let text = "Buffer tokenization check."

    var buffer = [UInt32](repeating: 0, count: 256)
    var span = buffer.mutableSpan
    let count = try model.tokenize(text: text, buffer: &span)

    let arrayTokens = try model.tokenize(text: text)

    expectNoDifference(count, arrayTokens.count)
    expectNoDifference(buffer.prefix(count).contains { $0 != 0 }, true)
  }

  @Test
  func `Throws Tokenize Error When Buffer Size Too Small`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.TokenizeError.bufferTooSmall) {
      try model.tokenize(text: "This text will not fit.", maxBufferSize: 1)
    }
  }

  @Test
  func `Scores Token Window With Tokens Array And Nil Range`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    let tokens = try model.tokenize(
      text: "Score this token window using the full token array."
    )

    let score = try model.scoreTokenWindow(tokens: tokens, range: nil, context: 0)

    withKnownIssue {
      assertSnapshot(of: score, as: .json, record: true)
    }
  }

  @Test
  func `Scores Token Window With Tokens Array And Subrange`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    let tokens = try model.tokenize(
      text: "Score this token window using a subrange of tokens."
    )

    let range = 1..<4
    let score = try model.scoreTokenWindow(tokens: tokens, range: range, context: 0)
    withKnownIssue {
      assertSnapshot(of: score, as: .json, record: true)
    }
  }

  @Test
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  func `Scores Token Window With Tokens Span And Nil Range`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    let tokens = try model.tokenize(
      text: "Score this token window using the full token span."
    )

    let span = tokens.span
    let score = try model.scoreTokenWindow(tokens: span, range: nil, context: 0)

    withKnownIssue {
      assertSnapshot(of: score, as: .json, record: true)
    }
  }

  @Test
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  func `Scores Token Window With Tokens Span And Subrange`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    let tokens = try model.tokenize(
      text: "Score this token window using a subrange of token spans."
    )

    let range = 1..<4
    let span = tokens.span
    let score = try model.scoreTokenWindow(tokens: span, range: range, context: 0)
    withKnownIssue {
      assertSnapshot(of: score, as: .json, record: true)
    }
  }

  @Test
  func `Image Embeddings`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: CactusLanguageModel.testVLMRequest
    )
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.imageEmbeddings(for: testImageURL)
    let embedding = Embedding(slug: model.configuration.modelSlug, vector: embeddings)

    withExpectedIssue {
      assertSnapshot(of: embedding, as: .json, record: true)
    }
  }

  @Test
  func `Throws Error When Trying To Embed Image With Non-VLM`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.EmbeddingsError.imageNotSupported) {
      try model.imageEmbeddings(for: testImageURL)
    }
  }

  @Test(.snapshots(record: .failed))
  func `Audio Embeddings`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(
      request: CactusLanguageModel.testTranscribeRequest
    )
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.audioEmbeddings(for: testAudioURL)
    let embedding = Embedding(slug: model.configuration.modelSlug, vector: embeddings)

    withKnownIssue {
      assertSnapshot(of: embedding, as: .json, record: true)
    }
  }

  @Test
  func `Throws Error When Trying To Embed Audio With Non-Audio Model`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.EmbeddingsError.audioNotSupported) {
      try model.audioEmbeddings(for: testAudioURL)
    }
  }

  private struct Embedding: Codable {
    let slug: String
    let vector: [Float]
  }

  @Test(arguments: modelRequests)
  func `Streams Same Response Content`(request: CactusLanguageModel.PlatformDownloadRequest)
    async throws
  {
    let modelURL = try await CactusLanguageModel.testModelURL(request: request)
    let model = try CactusLanguageModel(from: modelURL)

    var stream = ""
    let completion = try model.chatCompletion(
      messages: [
        .system("You are a philosopher, philosophize about any questions you are asked."),
        .user("What is the meaning of life?")
      ],
      options: CactusLanguageModel.ChatCompletion.Options(
        maxTokens: 1024,
        modelType: model.configurationFile.modelType ?? .qwen
      )
    ) { token in
      stream.append(token)
    }
    expectNoDifference(stream, completion.cleanedResponse)
  }

  @Test
  func `Throws Chat Completion Error When Buffer Size Too Small`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.ChatCompletionError.bufferSizeTooSmall) {
      try model.chatCompletion(
        messages: [
          CactusLanguageModel.ChatMessage(
            role: .system,
            content: "You are a philosopher, philosophize about any questions you are asked."
          ),
          CactusLanguageModel.ChatMessage(role: .user, content: "What is the meaning of life?")
        ],
        maxBufferSize: 300
      )
    }
  }

  @Test
  func `Throws Chat Completion Error When Buffer Size Zero`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.ChatCompletionError.bufferSizeTooSmall) {
      try model.chatCompletion(
        messages: [
          .system("You are a philosopher, philosophize about any questions you are asked."),
          .user("What is the meaning of life?")
        ],
        maxBufferSize: 0
      )
    }
  }

  @Test
  func `Streams Same Response As Audio Transcription`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(
      request: CactusLanguageModel.testTranscribeRequest
    )
    let model = try CactusLanguageModel(from: modelURL)

    var stream = ""
    let transcription = try model.transcribe(audio: testAudioURL, prompt: audioPrompt) {
      stream.append($0)
    }
    expectNoDifference(
      stream.replacingOccurrences(of: "<|startoftranscript|>", with: ""),
      transcription.response
    )
  }

  @Test
  func `Throws Transcription Error When Buffer Size Is Zero`() async throws {
    let modelURL = try await CactusLanguageModel.testAudioModelURL(
      request: CactusLanguageModel.testTranscribeRequest
    )
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.TranscriptionError.bufferSizeTooSmall) {
      try model.transcribe(audio: testAudioURL, prompt: audioPrompt, maxBufferSize: 0)
    }
  }

  @Test
  func `Throws Transcription Error When Model Does Not Support Audio`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.TranscriptionError.notSupported) {
      try model.transcribe(audio: testAudioURL, prompt: audioPrompt)
    }
  }

  @Test
  func `Derives Model Slug From Model URL If Not Provided`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let configuration = CactusLanguageModel.Configuration(modelURL: modelURL)
    expectNoDifference(configuration.modelSlug, CactusLanguageModel.testModelRequest.slug)
  }

  @Test
  func `Overrides Default Model Slug`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let configuration = CactusLanguageModel.Configuration(
      modelURL: modelURL,
      modelSlug: "custom-model"
    )
    expectNoDifference(configuration.modelSlug, "custom-model")
  }

  @Test
  func `Does Not Deallocate Model Pointer When Passed Externally`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let baseModel = try CactusLanguageModel(from: modelURL)
    do {
      _ = try CactusLanguageModel(
        model: baseModel.model,
        configuration: CactusLanguageModel.Configuration(modelURL: modelURL)
      )
    }

    #expect(throws: Never.self) {
      try baseModel.embeddings(for: "Some Text")
    }
  }

  @Test
  func `Embeddings From Model With Raw Pointer`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let modelPtr = try #require(cactus_init(modelURL.nativePath, nil))

    let model = try CactusLanguageModel(
      model: modelPtr,
      configuration: CactusLanguageModel.Configuration(modelURL: modelURL)
    )

    let embeddings = try model.embeddings(for: "Some Text")
    expectNoDifference(embeddings.isEmpty, false)
  }
}

final class CactusLanguageModelGenerationSnapshotTests: XCTestCase {
  func testBasicChatCompletion() async throws {
    struct Completion: Codable {
      let slug: String
      let completion: CactusLanguageModel.ChatCompletion
    }

    var completions = [Completion]()

    for request in modelRequests {
      let modelURL = try await CactusLanguageModel.testModelURL(request: request)
      let model = try CactusLanguageModel(from: modelURL)
      let completion = try model.chatCompletion(
        messages: [
          .system("You are a philosopher, philosophize about any questions you are asked."),
          .user("What is the meaning of life?")
        ]
      )
      completions.append(Completion(slug: request.slug, completion: completion))
    }
    withExpectedIssue {
      assertSnapshot(of: completions, as: .json, record: true)
    }
  }

  func testBasicFunctionCalling() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: CactusLanguageModel.testFunctionCallingModelRequest
    )
    let model = try CactusLanguageModel(from: modelURL)

    let completion = try model.chatCompletion(
      messages: [
        .system("You are a helpful weather assistant that can use tools."),
        .user("What is the weather in Santa Cruz?")
      ],
      options: CactusLanguageModel.ChatCompletion.Options(
        modelType: model.configurationFile.modelType ?? .qwen,
        forceFunctions: true
      ),
      functions: [
        CactusLanguageModel.FunctionDefinition(
          name: "get_weather",
          description: "Get the weather in a given location",
          parameters: .object(
            valueSchema: .object(
              properties: [
                "location": .object(
                  description: "City name",
                  valueSchema: .string(minLength: 1),
                  examples: ["San Francisco"]
                )
              ],
              required: ["location"]
            )
          )
        )
      ]
    )

    withExpectedIssue {
      assertSnapshot(of: completion, as: .json, record: true)
    }
  }

  func testMultipleFunctionCalls() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: CactusLanguageModel.testFunctionCallingModelRequest
    )
    let model = try CactusLanguageModel(from: modelURL)

    let completion = try model.chatCompletion(
      messages: [
        .system("You are a helpful weather assistant that can use tools."),
        .user("What is the weather and population in Berkeley?")
      ],
      functions: [
        CactusLanguageModel.FunctionDefinition(
          name: "get_weather",
          description: "Get the weather in a given location",
          parameters: .object(
            valueSchema: .object(
              properties: [
                "location": .object(
                  description: "City name",
                  valueSchema: .string(minLength: 1),
                  examples: ["San Francisco"]
                ),
                "units": .object(valueSchema: .string(), enum: ["celsius", "farenheit"])
              ],
              required: ["location"]
            )
          )
        ),
        CactusLanguageModel.FunctionDefinition(
          name: "get_population",
          description: "Gets the population of a given city",
          parameters: .object(
            valueSchema: .object(
              properties: [
                "location": .object(
                  description: "City name",
                  valueSchema: .string(minLength: 1),
                  examples: ["San Francisco"]
                )
              ],
              required: ["location"]
            )
          )
        )
      ]
    )

    withExpectedIssue {
      assertSnapshot(of: completion, as: .json, record: true)
    }
  }

  func testImageAnalysis() async throws {
    let url = try await CactusLanguageModel.testModelURL(
      request: CactusLanguageModel.testVLMRequest
    )
    let model = try CactusLanguageModel(from: url)

    let completion = try model.chatCompletion(
      messages: [
        .system(
          """
          You are an assistant who can analyze images of people, and predict their future after \
          they drink a Red Bull and a monster on the night before a final exam.
          """
        ),
        .user("What happens to the guy in the first image?", images: [testImageURL])
      ]
    )

    withExpectedIssue {
      assertSnapshot(of: completion, as: .json, record: true)
    }
  }

  func testAudioTranscription() async throws {
    struct Transcription: Codable {
      let slug: String
      let transcription: CactusLanguageModel.Transcription
    }

    let url = try await CactusLanguageModel.testAudioModelURL(
      request: CactusLanguageModel.testTranscribeRequest
    )
    let model = try CactusLanguageModel(from: url)

    let transcription = try model.transcribe(audio: testAudioURL, prompt: audioPrompt)

    withExpectedIssue {
      assertSnapshot(
        of: Transcription(slug: model.configuration.modelSlug, transcription: transcription),
        as: .json,
        record: true
      )
    }
  }
}

private let audioPrompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
private let modelRequests: [CactusLanguageModel.PlatformDownloadRequest] = [
  .lfm2_350m(),
  .qwen3_0_6b(),
  .gemma3_270mIt()
]
private let testImageURL = Bundle.module.url(forResource: "joe", withExtension: "png")!
private let testAudioURL = Bundle.module.url(forResource: "test", withExtension: "wav")!

extension CactusLanguageModel.ChatCompletion {
  fileprivate var cleanedResponse: String {
    var response = self.response
    for sequence in CactusLanguageModel.ChatCompletion.Options.defaultStopSequences {
      response = response.replacingOccurrences(of: sequence, with: "")
    }
    return response
  }
}
