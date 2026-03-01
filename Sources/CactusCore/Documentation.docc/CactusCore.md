# ``CactusCore``

Cross-platform Swift SDK for [Cactus](https://github.com/cactus-compute/cactus) inference.

## Overview

Cactus is a low-latency inference engine for mobile devices and wearables, allowing you to run high-performance AI locally in your app. Additionally, the engine supports hybrid cloud inference for when local inference isn't sufficient, and the engine itself will automatically perform this behavior.

This package supports all Apple platforms, Android, and Linux on ARM.

**Supported Engine Version:** 1.9

### Package Structure

This package exports 3 products.

- `Cactus` - The main library product.
  - This product exports `CactusCore`.
- `CactusCore` - The core of the library without macros bundled in.
  - This product exports `CXXCactusShims`.
- `CXXCactusShims` - A direct export of the Cactus FFI.

## Quick Start

To get started, you'll need to have URL to a model in Cactus format. This means you can either side-load a model yourself, or you can use ``CactusModelsDirectory`` to download a model. Afterwards, you can create a ``CactusAgentSession`` to begin conversing with the model.

```swift
import Cactus

Cactus.cactusCloudAPIKey = "OPTIONAL KEY HERE FOR HYBRID INFERENCE"

let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .lfm2_5_1_2bThinking()
)

let session = try CactusAgentSession(from: modelURL) {
  "You are a helpful assistant who can answer questions."
}
let message = CactusUserMessage {
  "What is the meaning of time?"
}
let completion = try await session.respond(to: message)
print(completion.output)
```

## Function Calling

Function calling is supported through the ``CactusFunction`` protocol, which can be passed to a ``CactusAgentSession``.

```swift
import Cactus

struct GetWeather: CactusFunction {
  @JSONSchema
  struct Input: Codable, Sendable {
    @JSONSchemaProperty(description: "The city to load the weather for.")
    let city: String
  }

  let name = "get_weather"
  let description = "Loads the weather for a city."

  func invoke(input: Input) async throws -> sending String {
    let weatherCondition = try await weather(for: city)
    return "The current weather for \(input.city) is: \(weatherCondition)"
  }
}

let session = try CactusAgentSession(
  from: modelURL,
  functions: [GetWeather()]
) {
  "You are a weather assistant who can get the current weather."
}
let message = CactusUserMessage {
  "What is the weather in San Francisco?"
}
let completion = try await session.respond(to: message)
print(completion.output)
```

The input type of the function must conform to `Decodable`, and the function must have a JSON Schema description for its parameters. You can use the `@JSONSchema` macro as shown in the above example to autosynthesize the schema.

If a model makes multiple function calls in a single prompt, they are executed in parallel by default (this is configurable), and the results are passed back to the model in the same order that the model invoked the functions in.

## Image Analysis

Certain models also support image analysis. You can analyze images by passing them into the prompt via ``CactusPromptContent``.

```swift
import Cactus

let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .lfm2Vl_450m()
)

let session = try CactusAgentSession(from: modelURL) {
  "You describe interesting parts of images."
}
let message = CactusUserMessage {
  "Describe this image in 1 sentence."
  CactusPromptContent(images: [imageURL])
}
let completion = try await session.respond(to: message)
print(completion.output)
```

## Speech to Text Transcription (STT)

Audio transcription is supported through the ``CactusSTTSession`` class. You can transcribe both audio files (WAV), and PCM buffers (16khz 16-bit mono).

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .parakeetCtc_1_1b()
)

let session = try CactusSTTSession(from: modelURL)

// WAV File
let request = CactusTranscription.Request(
  prompt: .default,
  content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let transcription = try await session.transcribe(request: request)
print(transcription.content)

// PCM Buffer
let pcmBytes: [UInt8] = [...]
let request = CactusTranscription.Request(
  prompt: .default,
  content: .pcm(pcmBytes)
)
let transcription = try await session.transcribe(request: request)
print(transcription.content)

// AVFoundation (Apple Platforms Only)
import AVFoundation

let buffer: AVAudioPCMBuffer = ...
let request = CactusTranscription.Request(
  prompt: .default,
  content: try .pcm(buffer)
)
let transcription = try await session.transcribe(request: request)
print(transcription.content)
```

### Whisper Prompts

For whisper models, you can rely on a special prompt constructor for whisper-style prompts.

```swift
import Cactus

let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .whisperSmall()
)

let session = try CactusSTTSession(from: modelURL)
let request = CactusTranscription.Request(
  prompt: .whipser(language: .english, includeTimestamps: true),
  content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let transcription = try await session.transcribe(request: request)
print(transcription.content)
```

## Streaming

Both ``CactusAgentSession`` and ``CactusSTTSession`` support streaming via ``CactusInferenceStream``.

```swift
// Agent Session

let session = CactusAgentSession(from: modelURL) {
  "You are a helpful assistant."
}

let message = CactusUserMessage {
  "What is the weather in San Francisco?"
}
let stream = try session.stream(to: message)
for await token in stream.tokens {
  print(token.stringValue, token.tokenId, token.messageStreamId)
}

let completion = try await stream.collectResponse()
print(completion.output)

// STT Session

let session = CactusSTTSession(from: modelURL)

let request = CactusTranscription.Request(
  prompt: .default,
  content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let stream = try session.transcriptionStream(request: request)
for await token in stream.tokens {
  print(token.stringValue, token.tokenId, token.messageStreamId)
}

let transcription = try await stream.collectResponse()
print(transcription.content)
```

## Live Transcription

You can also do live transcription through the ``CactusTranscriptionStream`` class, and by passing chunks of audio to transcribe to the stream.

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .parakeetCtc_1_1b()
)

let stream = try CactusTranscriptionStream(from: modelURL)
let recordingTask = Task {
  for try await chunk in stream {
    print(chunk)
  }
}


try await stream.process(buffer: chunk)
try await stream.process(buffer: chunk)
try await stream.process(buffer: chunk)

try await stream.finish()
_ = try await recordingTask.value
```

## Voice Activity Detection (VAD)

VAD is supported through the ``CactusVADSession`` class, and supports the same audio formats as ``CactusSTTSession``.

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .sileroVad()
)

let session = try CactusVADSession(from: modelURL)

// WAV File
let request = CactusVAD.Request(
  content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let vad = try await session.vad(request: request)
print(vad.segments)

// PCM Buffer
let pcmBytes: [UInt8] = [...]
let request = CactusVAD.Request(content: .pcm(pcmBytes))
let vad = try await session.vad(request: request)
print(vad.segments)

// AVFoundation (Apple Platforms Only)
import AVFoundation

let buffer: AVAudioPCMBuffer = ...
let request = CactusVAD.Request(content: try .pcm(buffer))
let vad = try await session.vad(request: request)
print(vad.segments)
```

## NPU Acceleration

Certain models also have a pro version on Apple platforms, which enable NPU acceleration through ANE. For models that support NPU acceleration, you can indicate the pro version you want inside the model download request.

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .lfm2Vl_450m(pro: .apple)
)

let modelURL = try await CactusModelsDirectory.shared.modelURL(
  for: .moonshineBase(pro: .apple)
)
```

## Model Storage

The ``CactusModelsDirectory`` class manages access to all models stored locally in your app, and it can even download and remove models directly on device.

```swift
let directory = CactusModelsDirectory(
  baseURL: .applicationSupportDirectory.appending(path: "models")
)

// Downloading

// directory.modelURL will only download if it cannot find the 
// model in the directory.
let modelURL = try await directory.modelURL(for: .whisperSmall())

let downloadTask = try await directory.downloadTask(for: .whisperSmall())
downloadTask.onProgress = { progress in
  print(progress)
}

// Removing

try directory.removeModel(with: .whisperSmall())
try directory.removeModels { $0.request == .whisperSmall() }
```

## Low Level FFI Wrapper

The ``CactusModel`` class is a non-Copyable, non-Sendable struct that provides a synchronous wrapper around the `cactus_model_t` pointer and C FFI. All higher level APIs in the SDK are built entirely off of this struct.

```swift
let model = try CactusModel(from: modelURL)

let turn = try model.complete(
  messages: [
    .system("You are a helpful assistant."),
    .user("What is the meaning of life?")
  ]
) { token, tokenId in
  print(token, tokenId) // Streaming
}
print(turn.response)

let transcription = try model.transcribe(
  audio: wavURL, 
  prompt: ""
) { token, tokenId in
  print(token, tokenId) // Streaming
}
print(transcription.response)
```

> Note: Since the struct is non-copyable, it therefore uses ownership semantics to manage the memory of the underlying model pointer. You can read the Swift Evolution [proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) for non-Copyable types to understand how they function at a deeper level.

The ``CactusModelActor`` is an actor variant of ``CactusModel`` which is properly Sendable, and supports background thread execution.

```swift
let model = try CactusModelActor(from: modelURL)

let turn = try await model.complete(
  messages: [
    .system("You are a helpful assistant."),
    .user("What is the meaning of life?")
  ]
) { token, tokenId in
  print(token, tokenId) // Streaming
}
print(turn.response)

let transcription = try await model.transcribe(
  audio: wavURL, 
  prompt: ""
) { token, tokenId in
  print(token, tokenId) // Streaming
}
print(transcription.response)
```

## Vector Embeddings

You can get embeddings for text, audio, and images through either ``CactusModel`` or ``CactusModelActor``.

```swift
// Synchronous

let model = try CactusModel(from: modelURL)

var embeddings = [2048 of Float](repeating: 0)
var span = embeddings.mutableSpan

try model.embeddings(for: "This is some text", buffer: &span)
try model.imageEmbeddings(for: imageURL, buffer: &span)
try model.audioEmbeddings(for: audioFileURL, buffer: &span)

// Async/Await

let model = try CactusModelActor(from: modelURL)

var embeddings = [2048 of Float](repeating: 0)
var span = embeddings.mutableSpan

try await model.embeddings(for: "This is some text", buffer: &span)
try await model.imageEmbeddings(for: imageURL, buffer: &span)
try await model.audioEmbeddings(for: audioFileURL, buffer: &span)
```

## Vector Indexing

You can use the low-level ``CactusIndex`` struct for vector indexing. ``CactusIndex`` is also a non-Copyable and non-Sendable struct like ``CactusModel``, which means that it uses ownership semantics to manage the memory to its underlying `cactus_model_t` pointer.

```swift
import Cactus

let model = try CactusModel(from: modelURL)
let index = try CactusIndex(
  from: .applicationSupportDirectory.appending(path: "my-index")
)

let embeddings = try model.embeddings(for: "Some text")

let document = CactusIndex.Document(
  id: 0,
  embeddings: emdeddings,
  content: "Some text"
)
try index.add(document: document)

let queryEmbeddings = try model.embeddings(for: "Another text")
let query = CactusIndex.Query(embeddings: queryEmbeddings)
let results = try index.query(query)

for result in results {
  print(result.documentId, result.score)
}
```

## Telemetry

You can enable and disable inference telemetry like so.

```swift
import Cactus

CactusTelemetry.setup()
await CactusTelemetry.disable()
```

## Observation

Many types in the library, such as ``CactusAgentSession``, ``CactusInferenceStream``, and ``CactusModel/DownloadTask`` conform to the `Observable` protocol from the Observation framework such that you can use them for live UI updates in SwiftUI views.

```swift
import SwiftUI
import Cactus

struct MyChatView: View {
  @State var session: CactusAgentSession

  var body: some View {
    VStack {
      ForEach(self.session.transcript) { entry in
        Text(entry.message.content)
      }
      if self.session.isResponding {
        ProgressView()
      }
    }
  }
}
```

## JSON Schema

The library ships with a built-in ``JSONSchema`` strong type including support for both validation and Codable types. You can easily generate a JSON schema for a struct through the `@JSONSchema` macro.

Additionally, the library supports encoding and decoding Codable values from an intermediate JSON representation.

```swift
@JSONSchema
struct MyValue: Codable {
  @JSONSchemaProperty(.string(pattern: /[0-9A-Za-z]+/))
  var property: String

  @JSONSchemaProperty(.integer(minimum: 10))
  var num: Int
}

let jsonValue = JSONSchema.Value.object([
  "property": "this is a string",
  "num": 10
])

// Validation

try JSONSchema.Validator.shared.validate(
  value: jsonValue, 
  with: MyValue.jsonSchema
)

// Codable Support

let decoded = try JSONSchema.Value.Decoder()
  .decode(MyValue.self, from: jsonValue)

let encoded: JSONSchema.Value = try JSONSchema.Value.Encoder()
  .encode(MyValue(property: "blob", num: 20))
```

## Future Roadmap

In no particular order.

- [`AnyLangauageModel`](https://github.com/mattt/AnyLanguageModel) backend.
- Reliable structured generation using the `@JSONSchema` macro and any EBNF grammar.
  - This requires CFG support in the upstream engine.
  - This would also support incremental structured streaming via [`StreamParsing`](https://github.com/mhayes853/swift-stream-parsing). 
- Higher-Level vector index abstractions.
- Integrations with more Apple native frameworks (eg. CoreAudio).
- Prefill API.

## Installation

You can add Swift Cactus to an Xcode project by adding it to your project as a package.

> https://github.com/mhayes853/swift-cactus

If you want to use Swift Cactus in a [SwiftPM](https://swift.org/package-manager/) project, it's as simple as adding it to your `Package.swift`.

```swift
dependencies: [
  .package(url: "https://github.com/mhayes853/swift-cactus", from: "2.0.0")
]
```

And then adding the product to any target that needs access to the library.

```swift
.product(name: "Cactus", package: "swift-cactus")
```

## License

This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/swift-cactus/blob/main/LICENSE) for details.
