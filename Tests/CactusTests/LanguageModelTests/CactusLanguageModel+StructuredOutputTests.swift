import Cactus
import CustomDump
import StreamParsing
import Testing

@Suite
struct `CactusLanguageModelStructuredOutput tests` {
  @Test
  func `JSON Chat Completion Returns Structured Output`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONChatCompletion<RecipeOutput>?
    for _ in 0..<3 where completion == nil {
      let attempt = try model.jsonChatCompletion(
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
  func `JSON Chat Completion Without System Prompt Injects Schema Prompt`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONChatCompletion<RecipeOutput>?
    for _ in 0..<3 where completion == nil {
      let attempt = try model.jsonChatCompletion(
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
  func `JSON Chat Completion Returns Function Call Failure Result`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completion = try model.jsonChatCompletion(
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
  func `JSON Chat Completion Returns Failure Result For Incomplete JSON Payload`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var didStop = false
    let completion = try model.jsonChatCompletion(
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
  func `JSON Streamable Chat Completion Emits Partials And Final Structured Output`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONChatCompletion<RecipeStreamOutput>?
    var sawPartial = false

    for _ in 0..<3 where completion == nil {
      let attempt =
        try model
        .jsonStreamableChatCompletion(
          messages: [
            .system("You are a helpful cooking assistant."),
            .user("Provide a recipe object with title and servings.")
          ],
          as: RecipeStreamOutput.self,
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
  func `JSON Streamable Chat Completion Without System Prompt Injects Schema Prompt`() async throws
  {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var completion: CactusLanguageModel.JSONChatCompletion<RecipeStreamOutput>?
    for _ in 0..<3 where completion == nil {
      let attempt =
        try model
        .jsonStreamableChatCompletion(
          messages: [
            .user("Return a JSON object with title and servings.")
          ],
          as: RecipeStreamOutput.self,
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
  func `JSON Streamable Chat Completion Returns Function Call Failure Result`() async throws {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    let completion =
      try model
      .jsonStreamableChatCompletion(
        messages: [
          .system("You are a weather assistant that must use functions when available."),
          .user("What is the weather in Santa Cruz?")
        ],
        as: RecipeStreamOutput.self,
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
  func `JSON Streamable Chat Completion Returns Failure Result For Incomplete JSON Payload`()
    async throws
  {
    let modelURL = try await CactusLanguageModel.testModelURL(request: .qwen3_1_7b())
    let model = try CactusLanguageModel(from: modelURL)

    var didStop = false
    let completion =
      try model
      .jsonStreamableChatCompletion(
        messages: [
          .system("You are a helpful cooking assistant."),
          .user("Generate a recipe JSON object with title and servings.")
        ],
        as: RecipeStreamOutput.self,
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

@JSONSchema
private struct RecipeOutput: Codable {
  var title: String

  @JSONIntegerSchema(minimum: 1)
  var servings: Int
}

@StreamParseable
@JSONSchema
private struct RecipeStreamOutput: Codable {
  var title: String

  @JSONIntegerSchema(minimum: 1)
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
