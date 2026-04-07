# Technical Assignment 2 — SPM LLM Module Repository

## Goal

Create a reusable Swift Package that encapsulates all local LLM responsibilities using Apple MLX.

## Scope

- Package type: Swift Package Manager module
- Responsibility boundary:
  - model loading
  - prompt preparation
  - inference/generation
  - optional streaming
- No UI logic inside the package

## Functional Requirements

1. Provide public API for one-shot generation:
   - input: user prompt (+ optional generation settings)
   - output: generated assistant text
2. Load local model from filesystem path (e.g., Llama 3.2 1B/3B compatible setup).
3. Prepare prompt/messages for inference in a reusable way.
4. Execute generation through MLX.
5. Provide a streaming API for incremental token output:
   - `AsyncThrowingStream<String, Error>` or equivalent
6. Return structured errors for:
   - missing/invalid model path
   - load failures
   - inference/runtime failures

## Non-Functional Requirements

1. Clean modular architecture:
   - `ModelLoader`
   - `PromptBuilder`
   - `Generator`
   - public facade/service
2. Testability:
   - protocol-based abstractions
   - unit tests for prompt building and error mapping
3. Reusability:
   - app-agnostic API
   - no coupling to CLI/GUI layer
4. Deterministic configuration defaults and documented tuning parameters.

## Public API Requirements

Expose a clean, minimal surface, e.g.:

- `LLMServiceProtocol`
- `generate(prompt:options:) async throws -> String`
- `stream(prompt:options:) async throws -> AsyncThrowingStream<String, Error>`

Define explicit config type:

- model path
- max tokens
- temperature/top-p (if supported)
- optional seed

