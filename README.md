# Swift Cactus
[![CI](https://github.com/mhayes853/swift-cactus/actions/workflows/ci.yml/badge.svg)](https://github.com/mhayes853/swift-cactus/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fswift-cactus%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mhayes853/swift-cactus)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fswift-cactus%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mhayes853/swift-cactus)

Swift bindings for [catus compute](https://github.com/cactus-compute/cactus).

## Overview

Cactus is a framework for deploying LLMs locally in your app, and can act as a suitable alternative to FoundationModels for your app by offering more model choices and better performance.

At the moment, this package provides a minimal and low-level Swifty interface above the Cactus C FFI, JSON Schema, Cactus Telemetry, and model downloading.

## Quick Start

You first must download the model you want to use using ``CactusModelsDirectory``, then you can create an instance of ``CactusLanguageModel`` with a local model `URL` to start generating.
```swift
import Cactus

let modelURL = try await CactusModelsDirectory.shared
  .modelURL(for: "qwen3-0.6")
let model = try CactusLanguageModel(from: modelURL)

let completion = try model.chatCompletion(
  messages: [
    .system("You are a philosopher, philosophize about anything."),
    .user("What is the meaning of life?")
  ]
)
```

> [!NOTE]
> The methods of `CactusLanguageModel` are synchronous and blocking, and the `CactusLanguageModel` class is also not Sendable. This gives you the flexibility to use the model in non-isolated and synchronous contexts, but you should almost certainly avoid using it directly on the main thread. If you need concurrent access to the model, you may want to consider wrapping it in an actor.
> ```swift
> final actor LanguageModelActor {
>   let model: CactusLanguageModel
>
>   init(model: sending CactusLanguageModel) {
>     self.model = model
>   }
>
>   func withIsolation<T, E: Error>(
>     perform operation: (isolated LanguageModelActor) throws(E) -> sending T
>   ) throws(E) -> sending T {
>     try operation(self)
>   }
> }
>
> @concurrent
> func chatInBackground(
>   with modelActor: LanguageModelActor
> ) async throws {
>   try await modelActor.withIsolation { @Sendable modelActor in
>     // You can access the model directly because the closure
>     // is isolated to modelActor.
>     let model = modelActor.model
>
>     // ...
>   }
> }
> ```

### Streaming

The ``CactusLanguageModel/chatCompletion(messages:options:maxBufferSize:tools:onToken:)`` method provides a callback the allows you to stream tokens as they come in.

```swift
let completion = try model.chatCompletion(
  messages: [
    .system("You are a philosopher, philosophize about anything."),
    .user("What is the meaning of life?")
  ]
) { token in
  print(token)
}
```

### Function Calling

You can pass a list of function definitions to the model, which the model can then invoke based on the schema of arguments you provide. The function calling format is based on the [JSON Schema format](https://datatracker.ietf.org/doc/html/draft-handrews-json-schema-validation-01).

```swift
let completion = try model.chatCompletion(
  messages: [
    .system("You are a helpful assistant that can use tools."),
    .user("What is the weather in San Francisco?")
  ],
  functions: [
    CactusLanguageModel.FunctionDefinition(
      name: "get_weather",
      description: "Get the weather in a given location",
      parameters: .object(
        type: .object(
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

// [
//   CactusLanguageModel.FunctionCall(
//     name: "get_weather",
//     arguments: ["location": "San Francisco"]
//   )
// ]
print(completion.functionCalls)
```

> [!NOTE]
> Smaller models may struggle to generate function arguments that match the ``JSONSchema`` you specify for the function. Therefore, the library provides a way to manually validate any value against the schema you provide to the model using the ``JSONSchema/Validator`` class.
> ```swift
> let functionDefinition = CactusLanguageModel.FunctionDefinition(
>   name: "search",
>   description: "Find something",
>   parameters: .object(
>     valueSchema: .object(
>       properties: [
>         "query": .object(valueSchema: .string(minLength: 1))
>       ]
>     )
>   )
> )
> let completion = try model.chatCompletion(
>   messages: messages,
>   functions: [functionDefinition]
> )
>
> for functionCall in completion.functionCalls {
>   try JSONSchema.Validator.shared.validate(
>     value: .object(functionCall.arguments),
>     with: functionDefinition.parameters
>   )
> }
> ```

### Embeddings

You can generate embeddings by passing a `MutableSpan` as a buffer to ``CactusLanguageModel/embeddings(for:buffer:)``, or you can alternatively obtain a `[Float]` directly by calling ``CactusLanguageModel/embeddings(for:maxBufferSize:)``.

```swift
let embeddings: [Float] = try model.embeddings(for: "This is some text")

// OR (Using InlineArray)

var embeddings = [2048 of Float](repeating: 0)
var span = embeddings.mutableSpan
try model.embeddings(for: "This is some text", buffer: &span)
```

You can use embeddings to match similar strings for searching purposes using algorithms such as cosine similarity.

```swift
func cosineSimilarity<C: Collection>(_ a: C, _ b: C) throws -> Double
where C.Element: BinaryFloatingPoint {
  guard a.count == b.count else {
    struct LengthError: Error {}
    throw LengthError()
  }
  var dot = 0.0, normA = 0.0, normB = 0.0
  var ia = a.startIndex, ib = b.startIndex
  while ia != a.endIndex {
    let x = Double(a[ia])
    let y = Double(b[ib])
    dot += x * y
    normA += x * x
    normB += y * y
    ia = a.index(after: ia)
    ib = b.index(after: ib)
  }
  let denom = (normA.squareRoot() * normB.squareRoot())
  return denom == 0 ? 0 : dot / denom
}

let fancy = try model.embeddings(for: "This is some fancy text")
let pretty = try model.embeddings(for: "This is some pretty text")

print(cosineSimilarity(fancy, pretty))
```

### Telemetry (iOS and macOS Only)

You can configure telemetry in the entry point of your app by calling ``CactusTelemetry/configure(_:logger:)``.

```swift
import Cactus
import SwiftUI

@main
struct MyApp: App {
  init() {
    CactusTelemetry.configure("token-from-cactus-dashboard")
  }

  // ...
}
```

`CactusLanguageModel` will automatically record telemetry events for every model initialization, chat completion, and embeddings generation, but you can also send telemetry events manually using ``CactusTelemetry/send(_:logger:)``. You can view the telemetry data in the cactus dashboard.

## Documentation
The documentation for releases and main are available here.
* [main](https://swiftpackageindex.com/mhayes853/swift-cactus/main/documentation/cactus/)
* [0.x.x](https://swiftpackageindex.com/mhayes853/swift-cactus/~/documentation/cactus/)

## Installation
You can add Swift Cactus to an Xcode project by adding it to your project as a package.
> https://github.com/mhayes853/swift-cactus

If you want to use Swift Cactus in a [SwiftPM](https://swift.org/package-manager/) project, it's as simple as adding it to your `Package.swift`.
``` swift
dependencies: [
  .package(url: "https://github.com/mhayes853/swift-cactus", from: "0.3.0")
]
```

And then adding the product to any target that needs access to the library.
```swift
.product(name: "Cactus", package: "swift-cactus")
```

## License
This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/swift-cactus/blob/main/LICENSE) for details.
