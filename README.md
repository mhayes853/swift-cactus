# Swift Cactus

A Swift wrapper for [catus compute](https://github.com/catus-compute/catus).

## Overview

Cactus is a framework for deploying LLMs locally in your app.

This package provides a minimal Swift wrapper around downloading models, and the cactus FFI.

## Quick Start

You first must download the model you want to use, then you can create an instance of `CactusLanguageModel` to start generating.
```swift
import Cactus

let modelURL = URL.applicationSupportDirectory.appendingPathComponent("catus-models/qwen")
try await CactusLanguageModel.download(slug: "qwen3-0.6", to: modelURL)
let model = try CactusLanguageModel(from: modelURL)

let completion = try model.chatCompletion(
  messages: [
    .system("You are a philosopher, philosophize about any questions you are asked."),
    .user("What is the meaning of life?")
  ],
  onToken: { token in
    // Streaming...
    print(token)
  }
)
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

// [
//   CactusLanguageModel.ToolCall(
//     name: "get_weather",
//     arguments: ["location": .string("San Francisco")]
//   )
// ]
print(completion.toolCalls)
```

### Embeddings

You can generate embeddings by passing a `MutableSpan` as a buffer, or you can alternatively obtain a `[Float]` directly.

```swift
let embeddings: [Float] = try model.embeddings(for: "This is some text")

// OR (Using InlineArray)

var embeddings = [2048 of Float](repeating: 0)
var span = embeddings.mutableSpan
try model.embeddings(for: "This is some text", buffer: &span)
```


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
This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/swift-operation/blob/main/LICENSE) for details.
