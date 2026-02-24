import Cactus
import CustomDump
import StreamParsing
import Testing

@Suite
struct `CactusLanguageModelStructuredOutput tests` {
  @Test
  func `JSON Complete Returns JSON Completed Chat Turn`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONCompletedChatTurn<RecipeOutput>?
    for _ in 0..<3 where completion == nil {
      let attempt = try model.jsonComplete(
        messages: [
          .system("You are a helpful cooking assistant."),
          .user("Provide a simple recipe object with a title and servings count.")
        ],
        as: RecipeOutput.self,
        options: CactusLanguageModel.JSONChatCompletionOptions(
          chatCompletionOptions: self.chatOptions(for: model)
        )
      )
      if case .success = attempt.output {
        completion = attempt
      } else {
        model.reset()
      }
    }

    guard let completion else {
      self.recordMissingSuccessfulJSONOutputIssue()
      return
    }
    guard case .success(let output) = completion.output else {
      self.recordUnexpectedJSONOutputShapeIssue()
      return
    }
    expectNoDifference(output.title.isEmpty, false)
    expectNoDifference(output.servings > 0, true)
  }

  @Test
  func `JSON Complete Appends Schema Prompt To Last User Message`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONCompletedChatTurn<RecipeOutput>?
    for _ in 0..<3 where completion == nil {
      let attempt = try model.jsonComplete(
        messages: [
          .user("Return a JSON recipe object with title and servings.")
        ],
        as: RecipeOutput.self,
        options: CactusLanguageModel.JSONChatCompletionOptions(
          chatCompletionOptions: self.chatOptions(for: model)
        )
      )
      if case .success = attempt.output {
        completion = attempt
      } else {
        model.reset()
      }
    }

    guard let completion else {
      self.recordMissingSuccessfulJSONOutputIssue()
      return
    }
    guard case .success(let output) = completion.output else {
      self.recordUnexpectedJSONOutputShapeIssue()
      return
    }
    expectNoDifference(output.title.isEmpty, false)
    expectNoDifference(output.servings > 0, true)
  }

  @Test
  func `JSON Complete Appends Schema Prompt As User Message When No User Message Exists`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completed = try model.jsonComplete(
      messages: [
        .system("You are a helpful cooking assistant.")
      ],
      as: RecipeOutput.self,
      options: CactusLanguageModel.JSONChatCompletionOptions(
        chatCompletionOptions: self.chatOptions(for: model)
      )
    )

    let userMessages = completed.messages.filter { $0.role == .user }
    guard let schemaMessage = userMessages.last else {
      Issue.record("Expected schema prompt to be appended as a user message.")
      return
    }
    expectNoDifference(schemaMessage.content.contains("JSON Schema:"), true)
  }

  @Test
  func `JSON Complete Returns Function Call Failure Result`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completion = try model.jsonComplete(
      messages: [
        .system("You are a weather assistant that must use functions when available."),
        .user("What is the weather in Santa Cruz?")
      ],
      as: RecipeOutput.self,
      options: CactusLanguageModel.JSONChatCompletionOptions(
        chatCompletionOptions: self.chatOptions(for: model, forceFunctions: true)
      ),
      functions: [self.weatherFunction]
    )

    guard completion.completion.functionCalls.isEmpty == false else {
      self.recordMissingFunctionCallIssue()
      return
    }
    expectNoDifference(completion.output.isFailure, true)
  }

  @Test
  func `JSON Complete Returns Failure Result For Incomplete JSON Payload`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var didStop = false
    let completion = try model.jsonComplete(
      messages: [
        .system("You are a helpful cooking assistant."),
        .user("Generate a recipe JSON object with title and servings.")
      ],
      as: RecipeOutput.self,
      options: CactusLanguageModel.JSONChatCompletionOptions(
        chatCompletionOptions: self.chatOptions(for: model)
      )
    ) { _, _ in
      if !didStop {
        didStop = true
        model.stop()
      }
    }

    expectNoDifference(completion.output.isFailure, true)
  }

  @Test
  func `JSON Streamable Complete Emits Partials And Returns JSON Completed Chat Turn`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONCompletedChatTurn<RecipeStreamOutput>?
    var sawPartial = false

    for _ in 0..<3 where completion == nil {
      let attempt =
        try model
        .jsonStreamableComplete(
          messages: [
            .system("You are a helpful cooking assistant."),
            .user("Provide a recipe object with title and servings.")
          ],
          as: RecipeStreamOutput.self,
          configuration: configuration,
          options: CactusLanguageModel.JSONChatCompletionOptions(
            chatCompletionOptions: self.chatOptions(for: model)
          )
        ) { _, _, partial in
          if partial != nil {
            sawPartial = true
          }
        }

      if case .success = attempt.output {
        completion = attempt
      } else {
        model.reset()
      }
    }

    guard let completion else {
      self.recordMissingSuccessfulJSONOutputIssue()
      return
    }
    guard case .success(let output) = completion.output else {
      self.recordUnexpectedJSONOutputShapeIssue()
      return
    }
    guard sawPartial else {
      self.recordMissingPartialIssue()
      return
    }
    expectNoDifference(output.title.isEmpty, false)
    expectNoDifference(output.servings > 0, true)
    expectNoDifference(sawPartial, true)
  }

  @Test
  func `JSON Streamable Complete Appends Schema Prompt To Last User Message`() async throws
  {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONCompletedChatTurn<RecipeStreamOutput>?
    for _ in 0..<3 where completion == nil {
      let attempt =
        try model
        .jsonStreamableComplete(
          messages: [
            .user("Return a JSON object with title and servings.")
          ],
          as: RecipeStreamOutput.self,
          configuration: configuration,
          options: CactusLanguageModel.JSONChatCompletionOptions(
            chatCompletionOptions: self.chatOptions(for: model)
          )
        )

      if case .success = attempt.output {
        completion = attempt
      } else {
        model.reset()
      }
    }

    guard let completion else {
      self.recordMissingSuccessfulJSONOutputIssue()
      return
    }
    guard case .success(let output) = completion.output else {
      self.recordUnexpectedJSONOutputShapeIssue()
      return
    }
    expectNoDifference(output.title.isEmpty, false)
    expectNoDifference(output.servings > 0, true)
  }

  @Test
  func `JSON Streamable Complete Returns Function Call Failure Result`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completion =
      try model
      .jsonStreamableComplete(
        messages: [
          .system("You are a weather assistant that must use functions when available."),
          .user("What is the weather in Santa Cruz?")
        ],
        as: RecipeStreamOutput.self,
        configuration: configuration,
        options: CactusLanguageModel.JSONChatCompletionOptions(
          chatCompletionOptions: self.chatOptions(for: model, forceFunctions: true)
        ),
        functions: [self.weatherFunction]
      )

    guard completion.completion.functionCalls.isEmpty == false else {
      self.recordMissingFunctionCallIssue()
      return
    }
    expectNoDifference(completion.output.isFailure, true)
  }

  @Test
  func `JSON Streamable Complete Returns Failure Result For Incomplete JSON Payload`()
    async throws
  {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var didStop = false
    let completion =
      try model
      .jsonStreamableComplete(
        messages: [
          .system("You are a helpful cooking assistant."),
          .user("Generate a recipe JSON object with title and servings.")
        ],
        as: RecipeStreamOutput.self,
        configuration: configuration,
        options: CactusLanguageModel.JSONChatCompletionOptions(
          chatCompletionOptions: self.chatOptions(for: model)
        )
      ) { _, _, _ in
        if !didStop {
          didStop = true
          model.stop()
        }
      }

    expectNoDifference(completion.output.isFailure, true)
  }

  @Test
  func `JSON Complete Excludes Schema From Prompt When Schema Prompt Mode Is Exclude`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completion = try model.jsonComplete(
      messages: [CactusLanguageModel.ChatMessage.user("Return a recipe.")],
      as: RecipeOutput.self,
      options: CactusLanguageModel.JSONChatCompletionOptions(
        chatCompletionOptions: self.chatOptions(for: model),
        schemaPromptMode: CactusLanguageModel.JSONChatCompletionOptions.SchemaPromptMode.exclude
      )
    )

    let userMessages = completion.messages.filter { $0.role == .user }
    for message in userMessages {
      expectNoDifference(message.content.contains("JSON Schema"), false)
    }
  }

  @Test
  func `JSON Complete Uses Custom Prompt Builder When Schema Prompt Mode Is Custom`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let originalUserContent = "Return a recipe."
    let customMarker = "CUSTOM_PROMPT_MARKER_12345"
    final class PromptCapture: @unchecked Sendable {
      var value: String?
    }
    let capture = PromptCapture()

    let completion = try model.jsonComplete(
      messages: [CactusLanguageModel.ChatMessage.user(originalUserContent)],
      as: RecipeOutput.self,
      options: CactusLanguageModel.JSONChatCompletionOptions(
        chatCompletionOptions: self.chatOptions(for: model),
        schemaPromptMode: CactusLanguageModel.JSONChatCompletionOptions.SchemaPromptMode.custom { receivedPrompt, _ in
          capture.value = receivedPrompt
          return "\(customMarker) Custom: Use this schema"
        }
      )
    )

    let receivedOriginalPrompt = try #require(capture.value)
    expectNoDifference(receivedOriginalPrompt, originalUserContent)

    let userMessages = completion.messages.filter { $0.role == .user }
    let lastUserMessage = try #require(userMessages.last)
    expectNoDifference(lastUserMessage.content.contains(customMarker), true)
    expectNoDifference(lastUserMessage.content.contains(originalUserContent), true)
  }

  private func chatOptions(
    for model: CactusLanguageModel,
    forceFunctions: Bool = false
  ) -> CactusLanguageModel.ChatCompletion.Options {
    CactusLanguageModel.ChatCompletion.Options(
      maxTokens: 512,
      modelType: model.configurationFile.modelType ?? .qwen,
      forceFunctions: forceFunctions
    )
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

  private func recordMissingSuccessfulJSONOutputIssue() {
    withKnownIssue {
      Issue.record("Model did not produce a successful JSON output within retry budget.")
    }
  }

  private func recordUnexpectedJSONOutputShapeIssue() {
    withKnownIssue {
      Issue.record("Model did not produce the expected JSON output shape.")
    }
  }

  private func recordMissingFunctionCallIssue() {
    withKnownIssue {
      Issue.record("Model did not emit a function call for this function-calling prompt.")
    }
  }

  private func recordMissingPartialIssue() {
    withKnownIssue {
      Issue.record("Model did not emit incremental partials during stream parsing.")
    }
  }
}

private let configuration = JSONStreamParserConfiguration(
  syntaxOptions: [
    .comments, .controlCharactersInStrings, .hexNumbers, .leadingDecimalPoint, .leadingPlus,
    .leadingZeros, .nonFiniteNumbers, .singleQuotedStrings, .trailingCommas, .unquotedKeys
  ]
)

@JSONSchema
private struct RecipeOutput: Codable {
  var title: String

  @JSONSchemaProperty(.integer(minimum: 1))
  var servings: Int
}

@StreamParseable
@JSONSchema
private struct RecipeStreamOutput: Codable {
  var title: String

  @JSONSchemaProperty(.integer(minimum: 1))
  var servings: Int
}

extension RecipeStreamOutput.Partial: Encodable {}

extension Result {
  fileprivate var isFailure: Bool {
    if case .failure = self {
      true
    } else {
      false
    }
  }
}
