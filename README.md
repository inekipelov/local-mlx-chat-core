# LocalMLXChatCore

Reusable Swift Package for local on-device text generation with Apple MLX.

`LocalMLXChatCore` keeps model loading, prompt preparation, one-shot generation, and streaming generation inside a standalone Swift Package so app targets do not need to own MLX-specific orchestration.

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.1+-F05138?logo=swift&logoColor=white" alt="Swift 6.1+"></a>
  <a href="https://developer.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-14.0+-000000?logo=apple" alt="macOS 14.0+"></a>
  <a href="https://developer.apple.com/xcode/"><img src="https://img.shields.io/badge/Xcode-16.4+-147EFB?logo=xcode&logoColor=white" alt="Xcode 16.4+"></a>
  <a href="https://developer.apple.com/apple-silicon/"><img src="https://img.shields.io/badge/Apple%20Silicon-Required-000000?logo=apple" alt="Apple Silicon required"></a>
  <a href="#installation"><img src="https://img.shields.io/badge/MLX%20Model-Installation%20Guide-5C2D91" alt="Local MLX-compatible model directory required"></a>
</p>

## Usage

```swift
// App code: import the package.
import Foundation
import LocalMLXChatCore

// App code: point to a local MLX-compatible model directory.
let configuration = LocalModelConfiguration(
    modelPath: URL(filePath: "/Users/you/Models/Llama-3.2-1B-Instruct-4bit"),
    generationPreset: .balanced
)

// App code: create the service once.
let service = LocalModelClient(configuration: configuration)

// One-shot generation: get the full reply.
let reply = try await service.generate(prompt: "Explain Swift Package Manager in two sentences.")
print(reply)

// Streaming generation: receive incremental chunks.
let stream = service.stream(
    prompt: "List three benefits of local inference.",
    options: GenerationOptions(maxTokens: 128, temperature: 0.6, topP: 0.9)
)

for await event in stream {
    switch event {
    case .chunk(let chunk):
        print(chunk, terminator: "")
    case .failed(let error):
        print("Streaming failed: \\(error)")
    case .finished:
        break
    }
}
print()
```

## Public API

### Types

| Type | Purpose |
| --- | --- |
| `LocalModelClient` | Main entry point for one-shot and streaming generation |
| `LocalModelConfiguration` | Defines the local model path and default generation preset |
| `GenerationPreset` | Curated built-in presets for common generation setups |
| `GenerationOptions` | Overrides generation settings per request |
| `LocalModelError` | Structured app-facing error surface |

### Methods

| Method | Returns | Purpose |
| --- | --- | --- |
| `generate(prompt:options:)` | `String` | Returns the full generated response |
| `stream(prompt:options:)` | `AsyncStream<LocalModelStreamEvent>` | Streams typed events with chunks, finish, and `LocalModelError` failures |

### Configuration

| Field | Meaning |
| --- | --- |
| `modelPath` | Local filesystem path to the MLX model directory |
| `generationPreset` | Built-in default setup used when a request does not provide explicit overrides |
| `maxTokens` | Maximum number of generated tokens |
| `temperature` | Sampling temperature |
| `topP` | Nucleus sampling value |
| `seed` | Optional deterministic seed for repeatable sampling |

### Presets

| Preset | Intended use | Settings |
| --- | --- | --- |
| `fast` | Lower latency and shorter answers | `maxTokens: 128`, `temperature: 0.6`, `topP: 0.9` |
| `balanced` | Default general-purpose setup | `maxTokens: 256`, `temperature: 0.7`, `topP: 0.95` |
| `precise` | Lower-variance answers when consistency matters | `maxTokens: 256`, `temperature: 0.2`, `topP: 0.9` |

## Errors

| Error | Meaning |
| --- | --- |
| `invalidModelPath` | The configured local model directory is missing or invalid |
| `modelLoadFailed` | The model could not be loaded from the provided path |
| `contextWindowExceeded` | The prepared prompt or requested output exceeded the available context window |
| `inferenceFailed` | Generation failed after the model was loaded |

`stream(prompt:options:)` reports failures through `LocalModelStreamEvent.failed(LocalModelError)` rather than `AsyncThrowingStream`.

## Installation

Add the package to your app's `Package.swift`:

```swift
.package(url: "https://github.com/your-org/local-mlx-chat-core", from: "0.1.0")
```

Then add the product to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "LocalMLXChatCore", package: "local-mlx-chat-core")
    ]
)
```

This repository does not include model weights.

You need a local MLX model directory on disk, for example `/Users/you/Models/Llama-3.2-1B-Instruct-4bit`.

That directory should include the files expected by `mlx-swift-lm`, typically including:

- one or more `*.safetensors` files
- tokenizer files
- model config files
- generation/chat template metadata when provided by the model package

`LocalMLXChatCore` performs a best-effort context-window validation before generation. It uses `config.json` metadata when available and skips preflight context validation when the model metadata does not expose a usable limit.

The package also applies a built-in internal truthfulness instruction layer before inference to reduce made-up factual answers without changing the public API.

## Migration Note

This release switches setup to preset-first configuration. `LocalModelConfiguration` now takes `generationPreset` and no longer exposes `contextWindowOverride` or `defaultGenerationOptions`.

## Manual Verification

A simple smoke test for a host app:

1. Point `LocalModelConfiguration.modelPath` at a valid local MLX model directory.
2. Call `generate(prompt:)` and verify that a full assistant reply is returned.
3. Call `stream(prompt:)` and verify that chunks arrive incrementally.
4. Try an invalid directory path and verify that `LocalModelError.invalidModelPath` is surfaced.
5. Try a very long prompt or a large `maxTokens` value and verify that `LocalModelError.contextWindowExceeded` is surfaced before inference starts.
