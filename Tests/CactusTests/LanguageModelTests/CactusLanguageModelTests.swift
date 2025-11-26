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
    expectNoDifference(error?.message.starts(with: "Failed to create model from:"), true)
  }

  @Test
  func `Successfully Creates Model From Downloaded Model`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    #expect(throws: Never.self) {
      try CactusLanguageModel(from: modelURL)
    }
  }

  @Test(.serialized, arguments: modelSlugs)
  func `Generates Embeddings`(slug: String) async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(slug: slug)
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.embeddings(for: "This is some text.")

    assertSnapshot(of: Embedding(slug: slug, vector: embeddings), as: .json)
  }

  @Test
  @available(*, deprecated)
  func `Properties Dump`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)

    assertSnapshot(of: model.properties, as: .dump)
  }

  @Test
  func `Throws Buffer Too Small Error When Buffer Size Too Small`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let model = try CactusLanguageModel(from: modelURL)
    #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
      try model.embeddings(for: "This is some text.", maxBufferSize: 20)
    }
  }

  @Test(.snapshots(record: .failed))
  func `Image Embeddings`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(slug: CactusLanguageModel.testVLMSlug)
    let model = try CactusLanguageModel(from: modelURL)

    let embeddings = try model.imageEmbeddings(for: testImageURL)
    let embedding = Embedding(slug: model.configuration.modelSlug, vector: embeddings)

    assertSnapshot(of: embedding, as: .json)
  }

  private struct Embedding: Codable {
    let slug: String
    let vector: [Float]
  }

  @Test(arguments: modelSlugs)
  func `Streams Same Response Content`(slug: String) async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(slug: slug)
    let model = try CactusLanguageModel(from: modelURL)

    let stream = Lock("")
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
      stream.withLock { $0.append(token) }
    }
    stream.withLock { expectNoDifference($0, completion.cleanedResponse) }
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
  func `Derives Model Slug From Model URL If Not Provided`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL()
    let configuration = CactusLanguageModel.Configuration(modelURL: modelURL)
    expectNoDifference(configuration.modelSlug, CactusLanguageModel.testModelSlug)
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
}

final class CactusLanguageModelGenerationSnapshotTests: XCTestCase {
  func testBasicChatCompletion() async throws {
    struct Completion: Codable {
      let slug: String
      let completion: CactusLanguageModel.ChatCompletion
    }

    var completions = [Completion]()

    for slug in modelSlugs {
      let modelURL = try await CactusLanguageModel.testModelURL(slug: slug)
      let model = try CactusLanguageModel(from: modelURL)
      let completion = try model.chatCompletion(
        messages: [
          .system("You are a philosopher, philosophize about any questions you are asked."),
          .user("What is the meaning of life?")
        ]
      )
      completions.append(Completion(slug: slug, completion: completion))
    }
    withExpectedIssue {
      assertSnapshot(of: completions, as: .json, record: true)
    }
  }

  func testBasicFunctionCalling() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(
      slug: CactusLanguageModel.testFunctionCallingModelSlug
    )
    let model = try CactusLanguageModel(from: modelURL)

    let completion = try model.chatCompletion(
      messages: [
        .system("You are a helpful weather assistant that can use tools."),
        .user("What is the weather in Santa Cruz?")
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
      slug: CactusLanguageModel.testFunctionCallingModelSlug
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
    let url = try await CactusLanguageModel.testModelURL(slug: CactusLanguageModel.testVLMSlug)
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
}

private let modelSlugs = ["lfm2-1.2b", "qwen3-0.6", "gemma3-270m", "smollm2-360m"]
private let testImageURL = Bundle.module.url(forResource: "joe", withExtension: "png")!

extension CactusLanguageModel.ChatCompletion {
  fileprivate var cleanedResponse: String {
    var response = self.response
    for sequence in CactusLanguageModel.ChatCompletion.Options.defaultStopSequences {
      response = response.replacingOccurrences(of: sequence, with: "")
    }
    return response
  }
}
