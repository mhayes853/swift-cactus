# Swift Cactus
[![CI](https://github.com/mhayes853/swift-cactus/actions/workflows/ci.yml/badge.svg)](https://github.com/mhayes853/swift-cactus/actions/workflows/ci.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fswift-cactus%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mhayes853/swift-cactus)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmhayes853%2Fswift-cactus%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mhayes853/swift-cactus)

A Swift client for [catus compute](https://github.com/cactus-compute/cactus).

## Overview

Cactus is a framework for deploying LLMs locally in your app, and can act as a suitable alternative to FoundationModels for your app by offering more model choices and better performance.

At the moment, this package provides a minimal Swifty interface above the Cactus C FFI, telemetry, and model downloading.

## Quick Start

You first must download the model you want to use, then you can create an instance of `CactusLanguageModel` to start generating.
```swift
import Cactus

let modelURL = URL.applicationSupportDirectory.appendingPathComponent("catus-models/qwen3-0.6")
try await CactusLanguageModel.download(slug: "qwen3-0.6", to: modelURL)
let model = try CactusLanguageModel(from: modelURL)

let completion = try model.chatCompletion(
  messages: [
    .system("You are a philosopher, philosophize about any questions you are asked."),
    .user("What is the meaning of life?")
  ]
)
```

> [!NOTE]
> The methods of `CactusLanguageModel` are synchronous and blocking, and the `CactusLanguageModel` class is also not Sendable. This gives you the flexibility to use the model on any thread, but you should almost certainly avoid running it directly on the main thread. Additionally, if you need concurrent access to the model, you may want to consider wrapping it in an actor.

### Streaming

The `chatCompletion` method provides a callback the allows you to stream tokens as they come in.

```swift
let completion = try model.chatCompletion(
  messages: [
    .system("You are a philosopher, philosophize about any questions you are asked."),
    .user("What is the meaning of life?")
  ]
) { token in
  print(token)
}
```

### Tool Calling

You can pass a list of tool definitions to the model, which the model can then invoke based on the schema of arguments you provide.

```swift
let completion = try model.chatCompletion(
  messages: [
    .system("You are a helpful assistant that can use tools."),
    .user("What is the weather in San Francisco?")
  ],
  tools: [
    CactusLanguageModel.ToolDefinition(
      name: "get_weather",
      description: "Get the weather in a given location",
      parameters: .object(
        type: .object(
          properties: [
            "location": .object(
              description: "City name, eg. 'San Francisco'",
              type: .string(minLength: 1),
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
//   CactusLanguageModel.ToolCall(
//     name: "get_weather",
//     arguments: ["location": .string("San Francisco")]
//   )
// ]
print(completion.toolCalls)
```

Your app is responsible for invoking code to fetch the weather for San Francisco, and passing the response back to the model as a new message.

### Embeddings

You can generate embeddings by passing a `MutableSpan` as a buffer, or you can alternatively obtain a `[Float]` directly.

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

You can configure telemetry in the entry point of your app.

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

`CactusLanguageModel` will automatically record telemetry events for every model initialization, chat completion, and emdeddings generation. You can view the telemetry data in the cactus dashboard.

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
  .package(url: "https://github.com/mhayes853/swift-cactus", from: "0.1.0")
]
```

And then adding the product to any target that needs access to the library.
```swift
.product(name: "Cactus", package: "swift-cactus")
```

## License
This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/swift-cactus/blob/main/LICENSE) for details.
