# ``Cactus``

Swift bindings for [catus compute](https://github.com/cactus-compute/cactus).

## Overview

Cactus is a framework for deploying LLMs locally in your app, and can act as a suitable alternative to FoundationModels for your app by offering more model choices and better performance.

At the moment, this package provides a minimal and low-level Swifty interface above the Cactus C FFI, JSON Schema, Cactus Telemetry, and model downloading.

## Quick Start

You first must download the model you want to use using ``CactusModelsDirectory``, then you can create an instance of ``CactusLanguageModel`` with a local model `URL` to start generating.
```swift
import Cactus

// (OPTIONAL) For NPU acceleration, email founders@cactuscompute.com to obtain a pro key.
try await Cactus.enablePro(key: "your_pro_key_here")

let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .qwen3_0_6b())
let model = try CactusLanguageModel(from: modelURL)

let completion = try model.chatCompletion(
  messages: [
    .system("You are a philosopher, philosophize about anything."),
    .user("What is the meaning of life?")
  ]
)
```

> Note: The methods of `CactusLanguageModel` are synchronous and blocking, and the `CactusLanguageModel` class is also not Sendable. This gives you the flexibility to use the model in non-isolated and synchronous contexts, but you should almost certainly avoid using it directly on the main thread. If you need concurrent access to the model, you may want to consider wrapping it in an actor.
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

The ``CactusLanguageModel/chatCompletion(messages:options:maxBufferSize:functions:onToken:)`` method provides a callback the allows you to stream tokens as they come in.

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

### Streaming Transcription

You can stream audio transcription results using ``CactusTranscriptionStream``, which vends an async sequence of
processed transcriptions.

```swift
import AVFoundation

let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .whisperSmall())
let stream = try CactusTranscriptionStream(modelURL: modelURL, contextSize: 2048)

let task = Task {
  for try await chunk in stream {
    print(chunk.confirmed, chunk.pending)
  }
}

let buffer = try AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
try await stream.insert(buffer: buffer)
let finalized = try await stream.finish()
print(finalized.confirmed)

_ = await task.value
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
        valueSchema: .object(
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

> Note: Smaller models may struggle to generate function arguments that match the ``JSONSchema`` you specify for the function. Therefore, the library provides a way to manually validate any value against the schema you provide to the model using the ``JSONSchema/Validator`` class.
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

### Vision

VLMs allow you to pass images to the model for analysis. You can pass an array of URLs to image files when creating a ``CactusLanguageModel/ChatMessage``.

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .lfm2Vl_450m())
let model = try CactusLanguageModel(from: modelURL)

let completion = try model.chatCompletion(
  messages: [
    .system("You are a helpful assistant."),
    .user("What is going on here?", images: [imageURL])
  ]
)
```

### Audio Transcription

Audio models allow you to transcribe audio files. You can pass the `URL` of an audio file to ``CactusLanguageModel/transcribe(audio:prompt:options:maxBufferSize:onToken:)`` in order to transcribe it.

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .whisperSmall())
let model = try CactusLanguageModel(from: modelURL)

// See https://huggingface.co/openai/whisper-small#usage for more info on how to structure a 
// whisper prompt.
let transcription = try model.transcribe(
  audio: audioFileURL, 
  prompt: "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
)
```

You can also transcribe directly from an `AVAudioPCMBuffer` directly.

```swift
import AVFoundation

let buffer = try AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
try model.transcribe(
  buffer: buffer, 
  prompt: "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
)
```

### Embeddings

You can generate embeddings by passing a `MutableSpan` as a buffer to ``CactusLanguageModel/embeddings(for:buffer:)-(_,MutableSpan<Float>)``, or you can alternatively obtain a `[Float]` directly by calling ``CactusLanguageModel/embeddings(for:maxBufferSize:)``.

```swift
let embeddings: [Float] = try model.embeddings(for: "This is some text")

// OR (Using InlineArray)

var embeddings = [2048 of Float](repeating: 0)
var span = embeddings.mutableSpan
try model.embeddings(for: "This is some text", buffer: &span)
```

Audio models and VLMs also support audio and image embeddings respectively.

```swift
let imageEmbeddings = try model.imageEmbeddings(for: imageURL)
let audioEmbeddings = try model.audioEmbeddings(for: audioFileURL)

// OR (Using InlineArray)

var embeddings = [2048 of Float](repeating: 0)
var span = embeddings.mutableSpan
try model.imageEmbeddings(for: imageURL, buffer: &span)
try model.imageEmbeddings(for: audioFileURL, buffer: &span)
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

### Android Setup

On Android certain APIs such as ``CactusModelsDirectory/shared`` require the use of the files directory. When your application launches on Android, make sure to set the `androidFilesDirectory` global variable to the path of the files directory.

```swift
import Cactus
import Android
import AndroidNativeAppGlue

@_silgen_name("android_main")
public func android_main(_ app: UnsafeMutablePointer<android_app>) {
  Cactus.androidFilesDirectory = URL(
    fileURLWithPath: app.pointee.activity.pointee.internalDataPath
  )
  
  // ...
}
```

Alternatively, you could export a JNI function to set the `androidFilesDirectory` global variable, and call that function from kotlin.

```swift
// In JNI module MyAppSwift
// 
// See https://github.com/swiftlang/swift-android-examples/tree/main/hello-swift-java 
// for more information on how to expose a Swift Package through JNI.
import Cactus

public func setAndroidFilesDirectory(_ path: String) {
  Cactus.androidFilesDirectory = URL(fileURLWithPath: path)
}
```
```kotlin
// In Android App
import com.example.myapp.MyAppSwift

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    MyAppSwift.setAndroidFilesDirectory(applicationContext.filesDir.absolutePath)
    // ...
  }
}
```

## Topics

### Model Downloading and Storage
- ``CactusModelsDirectory``
- ``CactusLanguageModel/DownloadTask``
- ``CactusLanguageModel/downloadModel(slug:to:configuration:onProgress:)``
- ``CactusLanguageModel/downloadModelTask(slug:to:configuration:)``
- ``CactusLanguageModel/Metadata``
- ``CactusLanguageModel/availableModels()``

### Language Models
- ``CactusLanguageModel``
- ``CactusLanguageModel/Properties``
- ``CactusLanguageModel/ConfigurationFile``
- ``CactusLanguageModel/Configuration``
- ``CactusLanguageModel/ModelType``
- ``CactusLanguageModel/ModelVariant``
- ``CactusLanguageModel/Precision``

### Chat Completions
- ``CactusLanguageModel/ChatCompletion``
- ``CactusLanguageModel/ChatCompletion/Options``
- ``CactusLanguageModel/chatCompletion(messages:options:maxBufferSize:functions:onToken:)``
- ``CactusLanguageModel/ChatMessage``
- ``CactusLanguageModel/MessageRole``
- ``CactusLanguageModel/ChatMessage/assistant(_:)``
- ``CactusLanguageModel/ChatMessage/system(_:)``
- ``CactusLanguageModel/ChatMessage/user(_:images:)``

### Audio Transcriptions
- ``CactusLanguageModel/Transcription``
- ``CactusLanguageModel/transcribe(audio:prompt:options:maxBufferSize:onToken:)``

### Embeddings
- ``CactusLanguageModel/embeddings(for:maxBufferSize:)``
- ``CactusLanguageModel/embeddings(for:buffer:)-(_,MutableSpan<Float>)``
- ``CactusLanguageModel/embeddings(for:buffer:)-(_,UnsafeMutableBufferPointer<Float>)``
- ``CactusLanguageModel/imageEmbeddings(for:maxBufferSize:)``
- ``CactusLanguageModel/imageEmbeddings(for:buffer:)-(_,MutableSpan<Float>)``
- ``CactusLanguageModel/imageEmbeddings(for:buffer:)-(_,UnsafeMutableBufferPointer<Float>)``
- ``CactusLanguageModel/audioEmbeddings(for:maxBufferSize:)``
- ``CactusLanguageModel/audioEmbeddings(for:buffer:)-(_,MutableSpan<Float>)``
- ``CactusLanguageModel/audioEmbeddings(for:buffer:)-(_,UnsafeMutableBufferPointer<Float>)``

### Function Calling
- ``CactusLanguageModel/FunctionDefinition``
- ``CactusLanguageModel/FunctionCall``

### Structured Output
- ``JSONSchema``
- ``JSONSchema/Object``
- ``JSONSchema/Value``
- ``JSONSchema/ValueSchema``
- ``JSONSchema/Validator``
- ``JSONSchema/Validator/validate(value:with:)``

### Telemetry
- ``CactusTelemetry``
- ``CactusTelemetry/Client``
- ``CactusTelemetry/configure(_:client:logger:)``

### Indexing
- ``CactusIndex``
