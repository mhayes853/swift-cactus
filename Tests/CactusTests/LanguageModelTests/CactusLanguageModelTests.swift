import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import Testing

extension BaseTestSuite {
  @Suite
  struct `CactusLanguageModel tests` {
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

    @Test
    func `Generates Embeddings`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)

      let embeddings = try model.embeddings(for: "This is some text.")
      assertSnapshot(of: embeddings, as: .dump)
    }

    @Test
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

    @Test
    func `Throws Buffer Too Small Error When Buffer Size Zero`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)
      #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
        try model.embeddings(for: "This is some text.", maxBufferSize: 0)
      }
    }

    @Test(
      arguments: [
        (CactusLanguageModel.SchemaType.number, "\"number\""),
        (.string, "\"string\""),
        (.boolean, "\"boolean\""),
        (.null, "\"null\""),
        (.array, "\"array\""),
        (.object, "\"object\""),
        (.types([.string, .number]), "[\"string\",\"number\"]")
      ]
    )
    @available(*, deprecated)
    func `Schema Type JSON`(value: CactusLanguageModel.SchemaType, json: String) throws {
      let data = try JSONEncoder().encode(value)
      expectNoDifference(String(decoding: data, as: UTF8.self), json)

      let decodedValue = try JSONDecoder().decode(CactusLanguageModel.SchemaType.self, from: data)
      expectNoDifference(value, decodedValue)
    }

    @Test
    func `Basic Chat Completion`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)

      let completion = try model.chatCompletion(
        messages: [
          .system("You are a philosopher, philosophize about any questions you are asked."),
          .user("What is the meaning of life?")
        ]
      )
      withKnownIssue {
        assertSnapshot(of: completion, as: .json, record: true)
      }
    }

    @Test
    func `Streams Same Response Content`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)

      let stream = Lock("")
      let completion = try model.chatCompletion(
        messages: [
          .system("You are a philosopher, philosophize about any questions you are asked."),
          .user("What is the meaning of life?")
        ]
      ) { token in
        stream.withLock { $0.append(token) }
      }
      stream.withLock { expectNoDifference($0, completion.response) }
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
    func `Basic Tool Calling`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)

      let completion = try model.chatCompletion(
        messages: [
          .system("You are a helpful weather assistant that can use tools."),
          .user("What is the weather in Santa Cruz?")
        ],
        tools: [
          CactusLanguageModel.ToolDefinition(
            name: "get_weather",
            description: "Get the weather in a given location",
            parameters: .object(
              valueSchema: .object(
                properties: [
                  "location": .object(
                    description: "City name, eg. 'San Francisco'",
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

      withKnownIssue {
        assertSnapshot(of: completion, as: .json, record: true)
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
}
