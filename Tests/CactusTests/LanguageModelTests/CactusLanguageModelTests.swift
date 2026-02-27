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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 0)
    }
  }

  @Test
  func `Attempt To Create Model From Non-Existent URL, Throws Error`() async throws {
    let error = #expect(throws: CactusLanguageModel.ModelCreationError.self) {
      _ = try CactusLanguageModel(from: temporaryModelDirectory())
    }
    expectNoDifference(error?.message.starts(with: "Failed to create model"), true)
  }

  @Test
  func `Successfully Creates Model From Downloaded Model`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    #expect(throws: Never.self) {
      _ = try CactusLanguageModel(from: modelURL)
    }
  }

  @Test(.serialized, arguments: modelRequests)
  func `Generates Embeddings`(request: CactusLanguageModel.PlatformDownloadRequest) async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: request)
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.embeddings(for: "This is some text.")

    withKnownIssue {
      assertSnapshot(
        of: Embedding(slug: request.slug, vector: embeddings),
        as: .json,
        record: true
      )
    }
  }

  @Test
  func `Throws Buffer Too Small Error When Buffer Size Too Small`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 20)
    }
  }

  @Test
  func `Tokenizes Text And Snapshots Output`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    let tokens = try model.tokenize(text: "Tokenize this text.")

    expectNoDifference(tokens.isEmpty, false)
    assertSnapshot(of: tokens, as: .json)
  }

  @Test
  @available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  func `Tokenizes Text Into MutableSpan Buffer`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.TokenizeError.bufferTooSmall) {
      try model.tokenize(text: "This text will not fit.", maxBufferSize: 1)
    }
  }

  @Test
  func `Scores Token Window With Tokens Array And Nil Range`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
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
      request: .lfm2Vl_450m()
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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.EmbeddingsError.imageNotSupported) {
      try model.imageEmbeddings(for: testImageURL)
    }
  }

  @Test
  func `Audio Embeddings`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .whisperSmall()
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
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
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
    let completion = try model.complete(
      messages: [
        .system("You are a philosopher, philosophize about any questions you are asked."),
        .user("What is the meaning of life?")
      ],
      options: CactusLanguageModel.Completion.Options(
        maxTokens: 1024,
        modelType: model.configurationFile.modelType ?? .qwen
      ),
      onToken: { token, _ in
        stream.append(token)
      }
    )
    expectNoDifference(stream, completion.completion.cleanedResponse)
  }

  @Test
  func `Complete Returns Completed Chat Turn`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completed = try model.complete(
      messages: [
        .system("You are a philosopher, philosophize about any questions you are asked."),
        .user("What is the meaning of life?")
      ]
    )

    expectNoDifference(completed.messages.last?.role, .assistant)
    expectNoDifference(completed.completion.response.isEmpty, false)
  }

  @Test
  func `Complete Returned Messages Can Be Reused For Next Complete`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)
    let options = CactusLanguageModel.Completion.Options(
      maxTokens: 128,
      modelType: model.configurationFile.modelType ?? .qwen
    )

    let first = try model.complete(
      messages: [
        .system("You are a concise assistant."),
        .user("Give one sentence about Swift.")
      ],
      options: options
    )

    let second = try model.complete(
      messages: first.messages + [.user("Now rephrase it in fewer words.")],
      options: options
    )

    expectNoDifference(second.messages.last?.role, .assistant)
    expectNoDifference(second.completion.response.isEmpty, false)
  }

  @Test
  func `Complete Includes Function Call Tokens In Returned Assistant Message`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completed = try model.complete(
      messages: [
        .system("You are a weather assistant that must use tools when available."),
        .user("What is the weather in Santa Cruz?")
      ],
      options: CactusLanguageModel.Completion.Options(
        maxTokens: 256,
        modelType: model.configurationFile.modelType ?? .qwen,
        forceFunctions: true
      ),
      functions: [self.weatherFunction]
    )

    guard completed.completion.functionCalls.isEmpty == false else {
      withKnownIssue {
        Issue.record("Model did not emit function calls for the tool-forced prompt.")
      }
      return
    }

    let assistantMessage = completed.messages.last(where: { $0.role == .assistant })?.content ?? ""
    expectNoDifference(assistantMessage.contains("<tool_call>"), true)
  }

  @Test(.disabled("Potential deadlock when running all tests."))
  func `Complete Reused Messages Reduce Prefill Tokens Compared To Reset Baseline`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .gemma3_270mIt())
    let model = try CactusLanguageModel(from: modelURL)

    let first = try model.complete(
      messages: [
        .system("You are a concise assistant."),
        .user("Explain closures in Swift in one sentence.")
      ]
    )

    let continuationMessages = first.messages + [.user("Now summarize that in five words.")]

    let hit = try model.complete(messages: continuationMessages)
    model.reset()
    let miss = try model.complete(messages: continuationMessages)

    expectNoDifference(hit.completion.prefillTokens <= miss.completion.prefillTokens, true)
  }

  @Test
  func `Throws Chat Completion Error When Buffer Size Too Small`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.ChatCompletionError.bufferSizeTooSmall) {
      try model.complete(
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

  private var weatherFunction: CactusLanguageModel.FunctionDefinition {
    CactusLanguageModel.FunctionDefinition(
      name: "get_weather",
      description: "Get weather in a location",
      parameters: .object(
        properties: [
          "location": .string(minLength: 1)
        ],
        required: ["location"]
      )
    )
  }

  @Test
  func `Throws Chat Completion Error When Buffer Size Zero`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.ChatCompletionError.bufferSizeTooSmall) {
      try model.complete(
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
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .whisperSmall()
    )
    let model = try CactusLanguageModel(from: modelURL)

    var stream = ""
    let transcription = try model.transcribe(audio: testAudioURL, prompt: audioPrompt) {
      stream.append($0)
    }
    expectNoDifference(stream.contains(transcription.response), true)
  }

  @Test
  func `Throws Transcription Error When Buffer Size Is Zero`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .whisperSmall()
    )
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.TranscriptionError.bufferSizeTooSmall) {
      try model.transcribe(audio: testAudioURL, prompt: audioPrompt, maxBufferSize: 0)
    }
  }

  @Test
  func `Throws Transcription Error When Model Does Not Support Audio`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.TranscriptionError.notSupported) {
      try model.transcribe(audio: testAudioURL, prompt: audioPrompt)
    }
  }

  @Test
  func `Derives Model Slug From Model URL If Not Provided`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let configuration = CactusLanguageModel.Configuration(modelURL: modelURL)
    expectNoDifference(
      configuration.modelSlug,
      CactusLanguageModel.PlatformDownloadRequest.lfm2_5_1_2bThinking().slug
    )
  }

  @Test
  func `Overrides Default Model Slug`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let configuration = CactusLanguageModel.Configuration(
      modelURL: modelURL,
      modelSlug: "custom-model"
    )
    expectNoDifference(configuration.modelSlug, "custom-model")
  }

  @Test
  func `Embeddings From Model With Raw Pointer`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let modelPtr = try #require(cactus_init(modelURL.nativePath, nil, false))

    let model = try CactusLanguageModel(
      model: modelPtr,
      configuration: CactusLanguageModel.Configuration(modelURL: modelURL)
    )

    let embeddings = try model.embeddings(for: "Some Text")
    expectNoDifference(embeddings.isEmpty, false)
  }

  @Test
  func `Throws RAG Error When Model Does Not Support RAG`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_5_1_2bThinking())
    let model = try CactusLanguageModel(from: modelURL)

    #expect(throws: CactusLanguageModel.RAGQueryError.ragNotSupported) {
      try model.ragQuery(query: "What is Swift?")
    }
  }

  @Test
  func `Throws Buffer Too Small Error When RAG Buffer Size Too Small`() async throws {
    let corpusURL = Bundle.module.url(forResource: "RAGCorpus", withExtension: nil)!
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .lfm2_5_1_2bInstruct()
    )
    let model = try CactusLanguageModel(
      from: modelURL,
      corpusDirectoryURL: corpusURL
    )

    #expect(throws: CactusLanguageModel.RAGQueryError.bufferSizeTooSmall) {
      try model.ragQuery(query: "What is async/await?", maxBufferSize: 100)
    }
  }

  @Test
  func `Throws Buffer Too Small Error When RAG Buffer Size Is Zero`() async throws {
    let corpusURL = Bundle.module.url(forResource: "RAGCorpus", withExtension: nil)!
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .lfm2_5_1_2bInstruct()
    )
    let model = try CactusLanguageModel(
      from: modelURL,
      corpusDirectoryURL: corpusURL
    )

    #expect(throws: CactusLanguageModel.RAGQueryError.bufferSizeTooSmall) {
      try model.ragQuery(query: "What is async/await?", maxBufferSize: 0)
    }
  }
}

final class CactusLanguageModelGenerationSnapshotTests: XCTestCase {
  func testComplete() async throws {
    struct Completion: Encodable {
      let slug: String
      let completion: CactusLanguageModel.Completion
      let messages: [CactusLanguageModel.ChatMessage]
    }

    let request = CactusLanguageModel.PlatformDownloadRequest.qwen3_1_7b()
    let modelURL = try await CactusLanguageModel.testModelURL(request: request)
    let model = try CactusLanguageModel(from: modelURL)
    let completed = try model.complete(
      messages: [
        .system("You are a philosopher, philosophize about any questions you are asked."),
        .user("What is the meaning of life?")
      ]
    )
    withExpectedIssue {
      assertSnapshot(
        of: Completion(
          slug: request.slug,
          completion: completed.completion,
          messages: completed.messages
        ),
        as: .json,
        record: true
      )
    }
  }

  func testBasicChatCompletion() async throws {
    struct Completion: Codable {
      let slug: String
      let completion: CactusLanguageModel.Completion
    }

    var completions = [Completion]()

    for request in modelRequests {
      let modelURL = try await CactusLanguageModel.testModelURL(request: request)
      let model = try CactusLanguageModel(from: modelURL)
      let completed = try model.complete(
        messages: [
          .system("You are a philosopher, philosophize about any questions you are asked."),
          .user("What is the meaning of life?")
        ]
      )
      completions.append(Completion(slug: request.slug, completion: completed.completion))
    }
    withExpectedIssue {
      assertSnapshot(of: completions, as: .json, record: true)
    }
  }

  func testBasicFunctionCalling() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .qwen3_0_6b()
    )
    let model = try CactusLanguageModel(from: modelURL)

    let completed = try model.complete(
      messages: [
        .system("You are a helpful weather assistant that can use tools."),
        .user("What is the weather in Santa Cruz?")
      ],
      options: CactusLanguageModel.Completion.Options(
        modelType: model.configurationFile.modelType ?? .qwen,
        forceFunctions: true
      ),
      functions: [
        CactusLanguageModel.FunctionDefinition(
          name: "get_weather",
          description: "Get the weather in a given location",
          parameters: .object(
            properties: [
              "location": .string(
                description: "City name",
                minLength: 1,
                examples: ["San Francisco"]
              )
            ],
            required: ["location"]
          )
        )
      ]
    )

    withExpectedIssue {
      assertSnapshot(of: completed.completion, as: .json, record: true)
    }
  }

  func testMultipleFunctionCalls() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      request: .qwen3_0_6b()
    )
    let model = try CactusLanguageModel(from: modelURL)

    let completed = try model.complete(
      messages: [
        .system("You are a helpful weather assistant that can use tools."),
        .user("What is the weather and population in Berkeley?")
      ],
      functions: [
        CactusLanguageModel.FunctionDefinition(
          name: "get_weather",
          description: "Get the weather in a given location",
          parameters: .object(
            properties: [
              "location": .string(
                description: "City name",
                minLength: 1,
                examples: ["San Francisco"]
              ),
              "units": .string(enum: ["celsius", "farenheit"])
            ],
            required: ["location"]
          )
        ),
        CactusLanguageModel.FunctionDefinition(
          name: "get_population",
          description: "Gets the population of a given city",
          parameters: .object(
            properties: [
              "location": .string(
                description: "City name",
                minLength: 1,
                examples: ["San Francisco"]
              )
            ],
            required: ["location"]
          )
        )
      ]
    )

    withExpectedIssue {
      assertSnapshot(of: completed.completion, as: .json, record: true)
    }
  }

  func testImageAnalysis() async throws {
    let url = try await CactusLanguageModel.testModelURL(
      request: .lfm2Vl_450m()
    )
    let model = try CactusLanguageModel(from: url)

    let completed = try model.complete(
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
      assertSnapshot(of: completed.completion, as: .json, record: true)
    }
  }

  func testAudioTranscription() async throws {
    struct Transcription: Codable {
      let slug: String
      let transcription: CactusLanguageModel.Transcription
    }

    let url = try await CactusLanguageModel.testModelURL(
      request: .whisperSmall()
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

  func testVAD() async throws {
    struct VADSnapshot: Codable {
      let slug: String
      let result: CactusLanguageModel.VADResult
    }

    let url = try await CactusLanguageModel.testModelURL(request: .sileroVad())
    let model = try CactusLanguageModel(from: url)
    let result = try model.vad(audio: testAudioURL)

    withExpectedIssue {
      assertSnapshot(
        of: VADSnapshot(slug: model.configuration.modelSlug, result: result),
        as: .json,
        record: true
      )
    }
  }

  #if canImport(AVFoundation)
    func testVADFromAVAudioPCMBuffer() async throws {
      struct VADSnapshot: Codable {
        let slug: String
        let result: CactusLanguageModel.VADResult
      }

      let url = try await CactusLanguageModel.testModelURL(request: .sileroVad())
      let model = try CactusLanguageModel(from: url)
      let pcmBuffer = try testAudioPCMBuffer()
      let result = try model.vad(buffer: pcmBuffer)

      withExpectedIssue {
        assertSnapshot(
          of: VADSnapshot(slug: model.configuration.modelSlug, result: result),
          as: .json,
          record: true
        )
      }
    }
  #endif

  func testRAGQuery() async throws {
    struct RAGResult: Codable {
      let slug: String
      let result: CactusLanguageModel.RAGQueryResult
    }

    let corpusURL = Bundle.module.url(forResource: "RAGCorpus", withExtension: nil)!
    let url = try await CactusLanguageModel.testModelURL(
      request: .lfm2_5_1_2bInstruct()
    )
    let model = try CactusLanguageModel(from: url, corpusDirectoryURL: corpusURL)

    let result = try model.ragQuery(query: "What is async/await?")

    withExpectedIssue {
      assertSnapshot(
        of: RAGResult(slug: model.configuration.modelSlug, result: result),
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

extension CactusLanguageModel.Completion {
  fileprivate var cleanedResponse: String {
    var response = self.response
    for sequence in CactusLanguageModel.Completion.Options.defaultStopSequences {
      response = response.replacingOccurrences(of: sequence, with: "")
    }
    return response
  }
}
