import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import Testing

extension BaseTestSuite {
  @Suite("CactusLanguageModel tests")
  struct CactusLanguageModelTests {
    @Test("Attempt To Create Model From Non-Existent URL, Throws Error")
    func attemptToCreateModelFromNonExistentURLThrowsError() async throws {
      let error = #expect(throws: CactusLanguageModel.ModelCreationError.self) {
        try CactusLanguageModel(from: temporaryDirectory())
      }
      expectNoDifference(error?.message.starts(with: "Failed to create model from:"), true)
    }

    @Test("Successfully Creates Model From Downloaded Model")
    func successfullyCreatesModelFromDownloadedModel() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      #expect(throws: Never.self) {
        try CactusLanguageModel(from: modelURL)
      }
    }

    @Test("Generates Embeddings")
    func generatesEmbeddings() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)

      let embeddings = try model.embeddings(for: "This is some text.")
      assertSnapshot(of: embeddings, as: .dump)
    }

    @Test("Throws Buffer Too Small Error When Buffer Size Too Small")
    func throwsBufferTooSmallErrorWhenBufferSizeTooSmall() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)
      #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
        try model.embeddings(for: "This is some text.", maxBufferSize: 20)
      }
    }

    @Test("Throws Buffer Too Small Error When Buffer Size Zero")
    func throwsBufferTooSmallErrorWhenBufferSizeZero() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)
      #expect(throws: CactusLanguageModel.EmbeddingsError.bufferTooSmall) {
        try model.embeddings(for: "This is some text.", maxBufferSize: 0)
      }
    }

    @Test(
      "Schema Value JSON",
      arguments: [
        (CactusLanguageModel.SchemaValue.number(1), "1"),
        (.string("blob"), "\"blob\""),
        (.boolean(true), "true"),
        (.null, "null"),
        (.array([.string("blob"), .number(1)]), "[\"blob\",1]"),
        (.array([]), "[]"),
        (.object([:]), "{}"),
        (.object(["key": .string("value")]), "{\"key\":\"value\"}")
      ]
    )
    func schemaValueJSON(value: CactusLanguageModel.SchemaValue, json: String) throws {
      let data = try JSONEncoder().encode(value)
      expectNoDifference(String(decoding: data, as: UTF8.self), json)

      let decodedValue = try JSONDecoder().decode(CactusLanguageModel.SchemaValue.self, from: data)
      expectNoDifference(value, decodedValue)
    }

    @Test("Basic Chat Completion")
    func basicChatCompletion() async throws {
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

    @Test("Streams Same Response Content")
    func streamsSameResponseContent() async throws {
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

    @Test("Throws Chat Completion Error When Buffer Size Too Small")
    func throwsChatCompletionErrorWhenBufferSizeTooSmall() async throws {
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

    @Test("Throws Chat Completion Error When Buffer Size Zero")
    func throwsChatCompletionErrorWhenBufferSizeZero() async throws {
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

    @Test("Basic Tool Calling")
    func basicToolCalling() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL()
      let model = try CactusLanguageModel(from: modelURL)

      let completion = try model.chatCompletion(
        messages: [
          .system("You are a helpful assistant that can use tools."),
          .user("What is the weather in San Francisco?")
        ],
        tools: [
          CactusLanguageModel.ToolDefinition(
            name: "get_weather",
            description: "Get the weather in a given location",
            parameters: CactusLanguageModel.ToolDefinition.Parameters(
              properties: [
                "location": CactusLanguageModel.ToolDefinition.Parameter(
                  type: .string,
                  description: "The location to get the weather for"
                )
              ],
              required: ["location"]
            )
          )
        ]
      )

      withKnownIssue {
        assertSnapshot(of: completion, as: .json, record: true)
      }
    }
  }
}
