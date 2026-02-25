import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import StreamParsing
import Testing

@Suite
struct `CactusAgentSession tests` {
  @Suite(.serialized)
  struct `AgentLoop tests` {
    @Test
    func `Simple Prompt Respond Returns Assistant Text Snapshot`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusLanguageModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let resolvedCompletion = try await session.respond(
        to: CactusUserMessage(
          "Say hello in one concise sentence.",
          maxTokens: .limit(512)
        )
      )

      expectNoDifference(resolvedCompletion.output.isEmpty, false)
      withKnownIssue {
        assertSnapshot(of: session.transcript, as: .json, record: true)
      }
    }

    @Test
    func `Respond Appends User And Assistant Messages To Transcript`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusLanguageModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      _ = try await session.respond(
        to: CactusUserMessage(
          "Answer with exactly one short sentence.",
          maxTokens: .limit(512)
        )
      )

      expectNoDifference(session.transcript.count >= 2, true)
      expectNoDifference(session.transcript[0].message.role, CactusLanguageModel.MessageRole.user)
      expectNoDifference(
        session.transcript.last?.message.role,
        CactusLanguageModel.MessageRole.assistant
      )
    }

    @Test
    func `Respond Appends All Completion Entries To Transcript In Order`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusLanguageModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let completion = try await session.respond(
        to: CactusUserMessage(
          "Give me one concise sentence about Swift.",
          maxTokens: .limit(512)
        )
      )

      let transcriptTail = Array(session.transcript.suffix(completion.entries.count))
      expectNoDifference(
        transcriptTail.map { $0.id },
        completion.entries.map { $0.transcriptEntry.id }
      )
      expectNoDifference(
        transcriptTail.map { $0.message.role },
        completion.entries.map { $0.transcriptEntry.message.role }
      )
    }

    @Test
    func
      `Simple Prompt Tool Execution Loop Supports Multiple Tool Calls And Returns Final Assistant Text Snapshot`()
      async throws
    {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_2_6b())

      var completion: CactusCompletion<String>?
      var transcript: CactusTranscript?
      for _ in 0..<3 where completion == nil {
        let model = try CactusLanguageModel(from: modelURL)
        let session = CactusAgentSession(
          model: model,
          functions: [ToolFactsFunction()],
          transcript: CactusTranscript()
        )
        let attempt: CactusCompletion<String>
        do {
          attempt = try await session.respond(
            to: CactusUserMessage(
              "Use the get_fact tool for both 'cactus' and 'swift', then summarize both facts.",
              maxTokens: .limit(512),
              forceFunctions: true
            )
          )
        } catch {
          continue
        }

        let toolMessageCount = session.transcript
          .filter {
            $0.message.role.rawValue == "tool" || $0.message.role.rawValue == "function"
          }
          .count
        if toolMessageCount >= 2 {
          completion = attempt
          transcript = session.transcript
        }
      }

      guard let resolvedCompletion = completion, let resolvedTranscript = transcript else {
        withKnownIssue {
          Issue.record("Model did not complete multi-tool loop within retry budget.")
        }
        return
      }

      let toolMessageCount =
        resolvedTranscript.filter {
          $0.message.role.rawValue == "tool" || $0.message.role.rawValue == "function"
        }
        .count
      expectNoDifference(toolMessageCount >= 2, true)
      withKnownIssue {
        assertSnapshot(of: resolvedTranscript, as: .json, record: true)
      }
    }

    @Test
    func `Simple Response Stream Emits Tokens In Order`() async throws {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusLanguageModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let stream = session.stream(
        to: try CactusUserMessage(
          "Respond with one short sentence about trees.",
          maxTokens: .limit(512)
        )
      )

      var streamedText = ""
      for try await token in stream.tokens {
        streamedText.append(token.stringValue)
      }

      let output = try await stream.collectResponse()
      expectNoDifference(streamedText.isEmpty, false)
      expectNoDifference(output.isEmpty, false)
      withKnownIssue {
        assertSnapshot(of: output, as: .dump, record: true)
      }
    }

    @Test
    func `Simple Structured Stream Emits Partials And Returns Decodable Final Output Snapshot`()
      async throws
    {
      let modelURL = try await CactusLanguageModel.testModelURL(request: .lfm2_2_6b())

      var output: RecipeStreamOutput?
      var partialCount = 0

      for _ in 0..<3 where output == nil {
        let model = try CactusLanguageModel(from: modelURL)
        let session = CactusAgentSession(model: model, transcript: CactusTranscript())
        let stream = session.stream(
          to: try CactusUserMessage(
            "Provide a JSON object with title and servings for a simple recipe.",
            maxTokens: .limit(512)
          ),
          generating: RecipeStreamOutput.self
        )

        do {
          var attemptPartialCount = 0
          for try await _ in stream.partials {
            attemptPartialCount += 1
          }
          partialCount += attemptPartialCount
        } catch {
          continue
        }

        output = try? await stream.collectResponse()
      }

      guard let resolvedOutput = output else {
        withKnownIssue {
          Issue.record("Structured streaming output was nil within retry budget.")
        }
        return
      }
      expectNoDifference(partialCount > 0, true)
      withKnownIssue {
        assertSnapshot(of: resolvedOutput, as: .json, record: true)
      }
    }

    struct ToolFactsFunction: CactusFunction, Sendable {
      typealias Output = String

      @JSONSchema
      struct Input: Codable, Sendable {
        let topic: String
      }

      let name = "get_fact"
      let description = "Returns a short fact for a topic"

      func invoke(input: sending Input) async throws -> sending String {
        switch input.topic.lowercased() {
        case "cactus": "Cacti store water in thick stems to survive arid climates."
        case "swift":
          "Swift is a type-safe language that emphasizes expressive syntax and performance."
        default: "No fact available for \(input.topic)."
        }
      }
    }

  }

  @Suite
  struct `ParallelToolCallExecutor tests` {
    @Test
    func `Execute Parallel Tool Calls Empty Input Returns Empty Results`() async throws {
      let returns = try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: [])
      expectNoDifference(returns.count, 0)
    }

    @Test
    func `Execute Parallel Tool Calls Single Tool Call Returns Single Result`() async throws {
      let functionCall = try CactusAgentSession.FunctionCall(
        function: EchoFunction(),
        rawFunctionCall: CactusLanguageModel.FunctionCall(
          name: "echo",
          arguments: ["text": .string("hello")]
        )
      )

      let returns = try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: [
        functionCall
      ])

      expectNoDifference(returns.count, 1)
      expectNoDifference(returns[0].name, "echo")
      let components = try returns[0].content.messageComponents()
      expectNoDifference(components.text, "hello")
    }

    @Test
    func `Execute Parallel Tool Calls Multiple Tool Calls Preserves Original Call Order`()
      async throws
    {
      let functionCalls = [
        try CactusAgentSession.FunctionCall(
          function: DelayedEchoFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "delayed_echo",
            arguments: ["text": .string("first"), "delayMs": .integer(100)]
          )
        ),
        try CactusAgentSession.FunctionCall(
          function: DelayedEchoFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "delayed_echo",
            arguments: ["text": .string("second"), "delayMs": .integer(1)]
          )
        )
      ]

      let returns = try await CactusAgentSession.executeParallelFunctionCalls(
        functionCalls: functionCalls
      )

      expectNoDifference(returns.count, 2)
      expectNoDifference(returns.map(\.name), ["delayed_echo", "delayed_echo"])
      expectNoDifference(
        try returns.map { try $0.content.messageComponents().text },
        ["first", "second"]
      )
    }

    @Test
    func `Execute Parallel Tool Calls Multiple Failures Throws Aggregated Error`() async throws {
      let functionCalls = [
        try CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "failable",
            arguments: ["value": .string("a"), "shouldFail": .boolean(true)]
          )
        ),
        try CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "failable",
            arguments: ["value": .string("b"), "shouldFail": .boolean(true)]
          )
        )
      ]

      let error = await #expect(throws: CactusAgentSession.ExecuteParallelFunctionCallsError.self) {
        _ = try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: functionCalls)
      }
      expectNoDifference(error?.errors.count, 2)
    }

    @Test
    func `Execute Parallel Tool Calls Mixed Success And Failure Throws Aggregated Error`()
      async throws
    {
      let functionCalls = [
        try CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "failable",
            arguments: ["value": .string("ok"), "shouldFail": .boolean(false)]
          )
        ),
        try CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "failable",
            arguments: ["value": .string("boom"), "shouldFail": .boolean(true)]
          )
        )
      ]

      let error = await #expect(throws: CactusAgentSession.ExecuteParallelFunctionCallsError.self) {
        _ = try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: functionCalls)
      }
      expectNoDifference(error?.errors.count, 1)
    }

    @Test
    func `Execute Parallel Tool Calls Aggregated Error Includes Function Throw Details`()
      async throws
    {
      let functionCalls = [
        try CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "failable",
            arguments: ["value": .string("a"), "shouldFail": .boolean(true)]
          )
        ),
        try CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          rawFunctionCall: CactusLanguageModel.FunctionCall(
            name: "failable",
            arguments: ["value": .string("b"), "shouldFail": .boolean(true)]
          )
        )
      ]

      let error = await #expect(throws: CactusAgentSession.ExecuteParallelFunctionCallsError.self) {
        _ = try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: functionCalls)
      }

      let functionThrows = try #require(error?.errors)
      expectNoDifference(functionThrows.count, 2)
      expectNoDifference(
        functionThrows.map { $0.functionCall.function.name },
        ["failable", "failable"]
      )
      expectNoDifference(
        functionThrows.compactMap(Self.rawValueArgument(from:)),
        ["a", "b"]
      )
      expectNoDifference(
        functionThrows.compactMap { functionThrow in
          TestToolError.value(from: functionThrow.error)
        },
        ["a", "b"]
      )
    }

    struct EchoFunction: CactusFunction, Sendable {
      typealias Output = String

      @JSONSchema
      struct Input: Codable, Sendable {
        let text: String
      }

      let name = "echo"
      let description = "Echoes input text"

      func invoke(input: sending Input) async throws -> sending String {
        input.text
      }
    }

    struct DelayedEchoFunction: CactusFunction, Sendable {
      typealias Output = String

      @JSONSchema
      struct Input: Codable, Sendable {
        let text: String
        let delayMs: Int
      }

      let name = "delayed_echo"
      let description = "Returns the input text after a delay"

      func invoke(input: sending Input) async throws -> sending String {
        try await Task.sleep(nanoseconds: UInt64(input.delayMs) * 1_000_000)
        return input.text
      }
    }

    struct FailableFunction: CactusFunction, Sendable {
      typealias Output = String

      @JSONSchema
      struct Input: Codable, Sendable {
        let value: String
        let shouldFail: Bool
      }

      let name = "failable"
      let description = "Returns value or throws"

      func invoke(input: sending Input) async throws -> sending String {
        if input.shouldFail {
          throw TestToolError.failed(input.value)
        }
        return input.value
      }
    }

    private enum TestToolError: Error {
      case failed(String)

      static func value(from error: any Error) -> String? {
        guard case .failed(let value) = error as? TestToolError else {
          return nil
        }
        return value
      }
    }

    private static func rawValueArgument(
      from functionThrow: CactusAgentSession.FunctionThrow
    ) -> String? {
      guard
        case .string(let value) = functionThrow.functionCall.rawFunctionCall.arguments["value"]
      else {
        return nil
      }
      return value
    }

  }
}

@StreamParseable
@JSONSchema
private struct RecipeStreamOutput: Codable {
  var title: String

  @JSONSchemaProperty(.integer(minimum: 1))
  var servings: Int
}

extension RecipeStreamOutput.Partial: Encodable {}
