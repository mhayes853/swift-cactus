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

      let returns = try await CactusAgentSession.executeParallelToolCalls(
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
        _ = try await CactusAgentSession.executeParallelToolCalls(functionCalls: functionCalls)
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
        _ = try await CactusAgentSession.executeParallelToolCalls(functionCalls: functionCalls)
      }
      expectNoDifference(error?.errors.count, 1)
    }
  }
}

private struct EchoFunction: CactusFunction, Sendable {
  typealias Input = EchoFunctionInput
  typealias Output = String

  let name = "echo"
  let description = "Echoes input text"

  func invoke(input: sending Input) async throws -> sending String {
    input.text
  }
}

private struct DelayedEchoFunction: CactusFunction, Sendable {
  typealias Input = DelayedEchoFunctionInput
  typealias Output = String

  let name = "delayed_echo"
  let description = "Returns the input text after a delay"

  func invoke(input: sending Input) async throws -> sending String {
    try await Task.sleep(nanoseconds: UInt64(input.delayMs) * 1_000_000)
    return input.text
  }
}

private struct FailableFunction: CactusFunction, Sendable {
  typealias Input = FailableFunctionInput
  typealias Output = String

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
}

@JSONSchema
private struct EchoFunctionInput: Codable, Sendable {
  let text: String
}

@JSONSchema
private struct DelayedEchoFunctionInput: Codable, Sendable {
  let text: String
  let delayMs: Int
}

@JSONSchema
private struct FailableFunctionInput: Codable, Sendable {
  let value: String
  let shouldFail: Bool
}
