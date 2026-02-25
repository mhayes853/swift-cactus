import Cactus
import CustomDump
import Foundation
import Testing

@Suite
struct `CactusAgentSession tests` {
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
    func `Execute Parallel Tool Calls Aggregated Error Includes Function Throw Details`() async throws {
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
      expectNoDifference(functionThrows.map { $0.functionCall.function.name }, ["failable", "failable"])
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
        guard case let .failed(value) = error as? TestToolError else {
          return nil
        }
        return value
      }
    }

    private static func rawValueArgument(
      from functionThrow: CactusAgentSession.FunctionThrow
    ) -> String? {
      guard
        case let .string(value) = functionThrow.functionCall.rawFunctionCall.arguments["value"]
      else {
        return nil
      }
      return value
    }

  }
}
