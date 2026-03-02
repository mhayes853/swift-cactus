import Cactus
import CustomDump
import Foundation
import SnapshotTesting
import Testing

#if canImport(Observation)
  import Observation
#endif

@Suite
struct `CactusAgentSession tests` {
  @Suite(.serialized)
  struct `AgentLoop tests` {
    @Test
    func `Simple Prompt Respond Returns Assistant Text Snapshot`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let resolvedCompletion = try await session.respond(
        to: CactusUserMessage {
          "Say hello in one concise sentence."
        }
      )

      expectNoDifference(resolvedCompletion.output.isEmpty, false)
      withKnownIssue {
        assertSnapshot(of: session.transcript, as: .json, record: true)
      }
    }

    @Test
    func `Simple Prompt Respond With Trailing Closure Message Returns Assistant Text`() async throws
    {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let resolvedCompletion = try await session.respond(
        to: CactusUserMessage(temperature: 0.7) {
          "Say hello in one concise sentence."
        }
      )

      expectNoDifference(resolvedCompletion.output.isEmpty, false)
      expectNoDifference(session.transcript.count == 2, true)
      expectNoDifference(session.transcript[0].message.role, CactusModel.MessageRole.user)
      expectNoDifference(
        session.transcript.last?.message.role,
        CactusModel.MessageRole.assistant
      )
    }

    @Test
    func `Multi Turn Conversation Maintains Context`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let firstTurn = try await session.respond(
        to: CactusUserMessage {
          "My favorite color is green. Please acknowledge this in one short sentence."
        }
      )
      let secondTurn = try await session.respond(
        to: CactusUserMessage {
          "What color did I say was my favorite? Reply with a thoughtful short sentence."
        }
      )

      expectNoDifference(firstTurn.output.isEmpty, false)
      expectNoDifference(secondTurn.output.isEmpty, false)
      expectNoDifference(session.transcript.count == 4, true)
      expectNoDifference(
        session.transcript.map(\.message.role),
        [.user, .assistant, .user, .assistant]
      )
      withKnownIssue {
        assertSnapshot(of: session.transcript, as: .json, record: true)
      }
    }

    @Test
    func `Multi Turn Conversation With Image Turn Maintains Context`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2Vl_450m())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      try await session.respond(
        to: CactusUserMessage {
          CactusPromptContent {
            "Describe what you see in this image in one short sentence."
            CactusPromptContent(images: [Self.testImageURL])
          }
        }
      )
      try await session.respond(
        to: CactusUserMessage {
          "What emotion is the smile evoking?"
        }
      )

      withKnownIssue {
        assertSnapshot(of: session.transcript, as: .json, record: true)
      }
    }

    @Test
    func `Multi Turn Conversation With System Prompt Maintains Context`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model) {
        "You are a helpful assistant that always responds in short, concise sentences."
      }

      let firstTurn = try await session.respond(
        to: CactusUserMessage {
          "My favorite color is green. Please acknowledge this."
        }
      )
      let secondTurn = try await session.respond(
        to: CactusUserMessage {
          "What color did I say was my favorite?"
        }
      )

      expectNoDifference(firstTurn.output.isEmpty, false)
      expectNoDifference(secondTurn.output.isEmpty, false)
      expectNoDifference(session.transcript.count == 5, true)
      expectNoDifference(
        session.transcript.map(\.message.role),
        [.system, .user, .assistant, .user, .assistant]
      )
      withKnownIssue {
        assertSnapshot(of: session.transcript, as: .json, record: true)
      }
    }

    @Test
    func `Respond Appends User And Assistant Messages To Transcript`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      try await session.respond(
        to: CactusUserMessage {
          "Answer with exactly one short sentence."
        }
      )

      expectNoDifference(session.transcript.count >= 2, true)
      expectNoDifference(session.transcript[0].message.role, CactusModel.MessageRole.user)
      expectNoDifference(
        session.transcript.last?.message.role,
        CactusModel.MessageRole.assistant
      )
    }

    @Test
    func `Respond Appends All Completion Entries To Transcript In Order`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let completion = try await session.respond(
        to: CactusUserMessage {
          "Give me one concise sentence about Swift."
        }
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
    func `Simple Prompt Respond Returns Completion Dump Snapshot`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let completion = try await session.respond(
        to: CactusUserMessage {
          "Say hello in one concise sentence."
        }
      )

      expectNoDifference(completion.output.isEmpty, false)
      expectNoDifference(completion.entries.isEmpty, false)
      withKnownIssue {
        assertSnapshot(of: completion, as: .dump, record: true)
      }
    }

    @Test
    func `Tool Call Respond Returns Completion Entries And Metrics Dump Snapshot`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2_2_6b())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(
        model: model,
        functions: [ToolFactsFunction()],
        transcript: CactusTranscript()
      )

      let completion = try await session.respond(
        to: CactusUserMessage(forceFunctions: true) {
          "Use the get_fact tool for both 'cactus' and 'swift', then summarize both facts."
        }
      )

      withKnownIssue {
        assertSnapshot(of: completion.entries, as: .dump, record: true)
      }
    }

    @Test
    func `Tool Call Respond Includes Metrics Only For Assistant Entries`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2_2_6b())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(
        model: model,
        functions: [ToolFactsFunction()],
        transcript: CactusTranscript()
      )

      let completion = try await session.respond(
        to: CactusUserMessage(forceFunctions: true) {
          "Use the get_fact tool for both 'cactus' and 'swift', then summarize both facts."
        }
      )

      expectNoDifference(
        completion.entries.contains { $0.transcriptEntry.message.role == .assistant },
        true
      )
      expectNoDifference(
        completion.entries.contains {
          $0.transcriptEntry.message.role == .assistant && $0.metrics != nil
        },
        true
      )
      expectNoDifference(
        completion.entries
          .filter { $0.transcriptEntry.message.isToolOrFunctionOutput }
          .allSatisfy { $0.metrics == nil },
        true
      )
    }

    @Test
    func
      `Simple Prompt Tool Execution Loop Supports Multiple Tool Calls And Returns Final Assistant Text Snapshot`()
      async throws
    {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2_2_6b())

      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(
        model: model,
        functions: [ToolFactsFunction()],
        transcript: CactusTranscript()
      )

      let resolvedCompletion = try await session.respond(
        to: CactusUserMessage(forceFunctions: true) {
          "Use the get_fact tool for both 'cactus' and 'swift', then summarize both facts."
        }
      )

      let resolvedTranscript = session.transcript

      let toolMessageCount =
        resolvedTranscript.filter {
          $0.message.isToolOrFunctionOutput
        }
        .count
      let hasAssistantOutput = resolvedCompletion.output.isEmpty == false
      expectNoDifference(hasAssistantOutput || toolMessageCount > 0, true)
      withKnownIssue {
        assertSnapshot(of: resolvedTranscript, as: .json, record: true)
      }
    }

    @Test
    func `Tool Call Delegate Is Invoked On Tool Call`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2_2_6b())

      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(
        model: model,
        functions: [ToolFactsFunction()],
        transcript: CactusTranscript()
      )
      let delegate = ToolCallDelegateSpy()
      session.delegate = delegate

      try await session.respond(
        to: CactusUserMessage(forceFunctions: true) {
          "Use the get_fact tool for 'cactus' and respond with only that fact."
        }
      )

      let delegateCallCount = delegate.callCount()
      let toolMessageCount =
        session.transcript
        .filter { $0.message.isToolOrFunctionOutput }
        .count

      expectNoDifference(delegateCallCount, toolMessageCount)
    }

    @Test
    func `Simple Response Stream Emits Tokens In Order`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(model: model, transcript: CactusTranscript())

      let stream = try session.stream(
        to: CactusUserMessage {
          "Respond with one short sentence about trees."
        }
      )

      var streamedText = ""
      for try await token in stream.tokens {
        streamedText.append(token.stringValue)
      }

      let completion = try await stream.collectResponse()
      expectNoDifference(streamedText.isEmpty, false)
      expectNoDifference(completion.output.isEmpty, false)
      expectNoDifference(completion.entries.isEmpty, false)
      withKnownIssue {
        assertSnapshot(of: completion.output, as: .dump, record: true)
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

    final class ToolCallDelegateSpy: CactusAgentSession.Delegate, @unchecked Sendable {
      private let invocations = Lock(0)

      func agentFunctionWillExecuteFunctions(
        _ session: CactusAgentSession,
        functionCalls: sending [CactusAgentSession.FunctionCall]
      ) async throws -> sending [CactusAgentSession.FunctionReturn] {
        self.invocations.withLock { $0 += 1 }
        return try await CactusAgentSession.executeParallelFunctionCalls(
          functionCalls: functionCalls
        )
      }

      func callCount() -> Int {
        self.invocations.withLock { $0 }
      }
    }

    @Test
    func `Is Responding Error Case Has Expected Message`() {
      expectNoDifference(
        CactusAgentSessionError.alreadyResponding.message,
        "The agent is already responding to another request."
      )
    }

    @Test
    func `Is Responding Is False When No Stream Is Active`() async throws {
      let session = try await Self.makeSession()
      expectNoDifference(session.isResponding, false)
    }

    @Test
    func `Is Responding Is True While Stream Is Active`() async throws {
      let session = try await Self.makeSession()
      let stream = try session.stream(
        to: CactusUserMessage {
          "Respond with one short sentence."
        }
      )

      expectNoDifference(session.isResponding, true)

      stream.stop()
      _ = try? await stream.collectResponse()
    }

    @Test
    func `Already Responding Rejects New Message`() async throws {
      let session = try await Self.makeSession()
      let stream = try session.stream(
        to: CactusUserMessage {
          "Write one short sentence about cacti."
        }
      )

      expectNoDifference(session.isResponding, true)

      let error = await #expect(throws: CactusAgentSessionError.self) {
        try await session.respond(
          to: CactusUserMessage {
            "This second request should fail while the first stream is active."
          }
        )
      }

      let caughtError = try #require(error)
      expectNoDifference(caughtError.underlyingError == nil, true)
      expectNoDifference(caughtError.message, CactusAgentSessionError.alreadyResponding.message)

      stream.stop()
      _ = try? await stream.collectResponse()
    }

    @Test
    func `Respond Throws Invalid User Message Error For Throwing User Content`() async throws {
      let session = try await Self.makeSession()

      let error = await #expect(throws: CactusAgentSessionError.self) {
        try await session.respond(
          to: CactusUserMessage(content: CactusPromptContent(ThrowingPromptRepresentable()))
        )
      }

      expectNoDifference(try #require(error).underlyingError is ThrowingPromptError, true)
      expectNoDifference(session.isResponding, false)
    }

    @Test
    func `Respond Throws Invalid System Prompt Error For Throwing System Content`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(
        model: model,
        systemPrompt: CactusPromptContent(ThrowingPromptRepresentable())
      )

      let error = await #expect(throws: CactusAgentSessionError.self) {
        try await session.respond(
          to: CactusUserMessage {
            "Write one short sentence about cacti."
          }
        )
      }

      expectNoDifference(try #require(error).underlyingError is ThrowingPromptError, true)
      expectNoDifference(session.isResponding, false)
    }

    @Test
    func `Function Error Prevents User Message From Being Added To Transcript`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2_2_6b())
      let model = try CactusModel(from: modelURL)

      final class ThrowingDelegate: CactusAgentSession.Delegate, Sendable {
        func agentFunctionWillExecuteFunctions(
          _ session: CactusAgentSession,
          functionCalls: sending [CactusAgentSession.FunctionCall]
        ) async throws -> sending [CactusAgentSession.FunctionReturn] {
          struct SomeError: Error {}
          throw SomeError()
        }
      }

      let session = CactusAgentSession(
        model: model,
        functions: [ToolFactsFunction()]
      ) {
        "You are a helpful assistant that can get facts about cool things. Use the get_fact tool to do so."
      }
      session.delegate = ThrowingDelegate()
      
      let response = try? await session.respond(
        to: CactusUserMessage(forceFunctions: true) {
          "Use the get_fact tool for 'cactus' and respond with only that fact."
        }
      )

      if response == nil {
        expectNoDifference(session.transcript.count, 1)
        expectNoDifference(session.transcript.first?.message.role, .system)
      } else {
        withKnownIssue { Issue.record("Model did not invoke get_fact tool.") }
      }
    }

    @Test
    func `Reset Clears Transcript`() async throws {
      let session = try await Self.makeSession()

      try await session.respond(
        to: CactusUserMessage {
          "Write one short sentence about cacti."
        }
      )
      expectNoDifference(session.transcript.isEmpty, false)

      await session.reset()

      expectNoDifference(session.transcript.isEmpty, true)
    }

    @Test
    func `Reset Stops Ongoing Inference Stream`() async throws {
      let session = try await Self.makeSession()
      let stream = try session.stream(
        to: CactusUserMessage {
          "Write one short sentence about cacti."
        }
      )

      expectNoDifference(session.isResponding, true)

      await session.reset()

      await #expect(throws: CancellationError.self) {
        _ = try await stream.collectResponse()
      }
      expectNoDifference(stream.isStreaming, false)
    }

    @Test
    func `Reset Sets Is Responding To False`() async throws {
      let session = try await Self.makeSession()
      let stream = try session.stream(
        to: CactusUserMessage {
          "Write one short sentence about cacti."
        }
      )

      expectNoDifference(session.isResponding, true)

      await session.reset()
      _ = try? await stream.collectResponse()

      expectNoDifference(session.isResponding, false)
    }

    @Test
    func `Stop Stops Ongoing Inference Stream`() async throws {
      let session = try await Self.makeSession()
      let stream = try session.stream(
        to: CactusUserMessage(maxTokens: 1024) {
          "Write a long, detailed paragraph about cacti and succulents."
        }
      )

      expectNoDifference(session.isResponding, true)

      await session.stop()

      await #expect(throws: CancellationError.self) {
        _ = try await stream.collectResponse()
      }
      expectNoDifference(stream.isStreaming, false)
    }

    @Test
    func `Stop Sets Is Responding To False`() async throws {
      let session = try await Self.makeSession()
      let stream = try session.stream(
        to: CactusUserMessage(maxTokens: 1024) {
          "Write a long, detailed paragraph about cacti and succulents."
        }
      )

      expectNoDifference(session.isResponding, true)

      await session.stop()

      expectNoDifference(session.isResponding, false)

      _ = stream
    }

    @Test
    func `Canceling Respond Task Cancels Stream And Ends Session`() async throws {
      let modelURL = try await CactusModel.testModelURL(request: .lfm2_2_6b())
      let model = try CactusModel(from: modelURL)
      let session = CactusAgentSession(
        model: model,
        functions: [SlowToolFunction()],
        transcript: CactusTranscript()
      )

      let responseTask = Task {
        try await session.respond(
          to: CactusUserMessage(maxTokens: 1024, forceFunctions: true) {
            "Use the slow_echo tool and return its output exactly."
          }
        )
      }

      try await Task.sleep(for: .milliseconds(150))

      responseTask.cancel()

      await #expect(throws: CancellationError.self) {
        _ = try await responseTask.value
      }
      expectNoDifference(session.isResponding, false)
    }

    struct SlowToolFunction: CactusFunction, Sendable {
      typealias Output = String

      @JSONSchema
      struct Input: Codable, Sendable {
        let text: String
      }

      let name = "slow_echo"
      let description = "Returns text after a delay"

      func invoke(input: sending Input) async throws -> sending String {
        try await Task.sleep(for: .seconds(2))
        return input.text
      }
    }

    struct ThrowingPromptRepresentable: CactusPromptRepresentable {
      var promptContent: CactusPromptContent {
        get throws {
          throw ThrowingPromptError.failed
        }
      }
    }

    enum ThrowingPromptError: Error {
      case failed
    }

    private static func makeSession() async throws -> CactusAgentSession {
      let modelURL = try await CactusModel.testModelURL(request: .gemma3_270mIt())
      let model = try CactusModel(from: modelURL)
      return CactusAgentSession(model: model, transcript: CactusTranscript())
    }

    private static var testImageURL: URL {
      Bundle.module.url(forResource: "sean_avatar", withExtension: "jpeg")!
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
      let functionCall = CactusAgentSession.FunctionCall(
        function: EchoFunction(),
        arguments: ["text": .string("hello")]
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
        CactusAgentSession.FunctionCall(
          function: DelayedEchoFunction(),
          arguments: ["text": .string("first"), "delayMs": .integer(100)]
        ),
        CactusAgentSession.FunctionCall(
          function: DelayedEchoFunction(),
          arguments: ["text": .string("second"), "delayMs": .integer(1)]
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
        CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          arguments: ["value": .string("a"), "shouldFail": .boolean(true)]
        ),
        CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          arguments: ["value": .string("b"), "shouldFail": .boolean(true)]
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
        CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          arguments: ["value": .string("ok"), "shouldFail": .boolean(false)]
        ),
        CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          arguments: ["value": .string("boom"), "shouldFail": .boolean(true)]
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
        CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          arguments: ["value": .string("a"), "shouldFail": .boolean(true)]
        ),
        CactusAgentSession.FunctionCall(
          function: FailableFunction(),
          arguments: ["value": .string("b"), "shouldFail": .boolean(true)]
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
        case .string(let value) = functionThrow.functionCall.arguments["value"]
      else {
        return nil
      }
      return value
    }

    @Test
    func `Execute Parallel Tool Calls Cancellation Propagates To All Running Tools`() async throws {
      let (stream, continuation) = AsyncStream<Void>.makeStream()
      var iter = stream.makeAsyncIterator()

      let function = CancellationTrackingFunction(continuation: continuation)

      let functionCalls = [
        CactusAgentSession.FunctionCall(
          function: function,
          arguments: ["id": .string("tool1"), "delayMs": .integer(500)]
        )
      ]

      let innerTask = Task {
        do {
          _ = try await CactusAgentSession.executeParallelFunctionCalls(functionCalls: functionCalls)
        } catch is CancellationError {
          let didCancel = await function.didCancel
          expectNoDifference(didCancel, true)
          throw CancellationError()
        }
      }

      await iter.next()
      innerTask.cancel()

      await #expect(throws: CancellationError.self) {
        try await innerTask.value
      }
    }

    actor CancellationTrackingFunction: CactusFunction, Sendable {
      private let continuation: AsyncStream<Void>.Continuation?

      typealias Output = String

      var didCancel = false

      @JSONSchema
      struct Input: Codable, Sendable {
        let id: String
        let delayMs: Int
      }

      let name = "cancellation_tracking"
      let description = "Tracks cancellation"

      init(continuation: AsyncStream<Void>.Continuation?) {
        self.continuation = continuation
      }

      func invoke(input: sending Input) async throws -> sending String {
        continuation?.yield()
        do {
          try await Task.sleep(nanoseconds: UInt64(input.delayMs) * 1_000_000)
        } catch is CancellationError {
          self.didCancel = true
          throw CancellationError()
        }
        return "completed \(input.id)"
      }
    }

  }
}

extension CactusModel.ChatMessage {
  fileprivate var isToolOrFunctionOutput: Bool {
    self.role == .tool
  }
}
