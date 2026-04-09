# Plain-Text Prompting Fallback Design

## Summary

`LocalMLXChatCore` currently delegates prompt preparation to `mlx-swift-lm` by
building `UserInput(prompt:)` and calling `ModelContainer.prepare(input:)`.
When a model directory does not include chat template metadata,
`mlx-swift-lm` attempts chat formatting, prints a warning, and falls back to
joining message content as plain text.

This design makes that fallback explicit inside `LocalMLXChatCore`. The package
will detect whether the model directory supports chat templating and choose one
of two internal prompt-preparation modes:

- `chatTemplateAvailable`
- `plainText`

For plain-text models, the package will bypass the dependency's chat-template
fallback path and directly encode the final prompt text. Public API, error
mapping, and streaming behavior remain unchanged.

## Problem

For models such as `Llama-3.2-1B` that do not ship `chat_template.json` and do
not declare `chat_template` in `tokenizer_config.json`, host applications
receive this low-level warning from `mlx-swift-lm`:

`No chat template was included or provided, so converting messages to simple text format.`

That warning is technically correct but undesirable for this package:

- it is emitted by a dependency rather than by `LocalMLXChatCore`
- it exposes an internal fallback strategy to host applications
- it signals an expected capability difference, not a runtime failure
- it leaves the package relying on dependency fallback instead of intentional behavior

## Goals

- Detect missing chat-template support before generation starts.
- Treat plain-text prompting as a supported internal mode, not as an error.
- Avoid the dependency warning for models without chat-template metadata.
- Preserve the current public API.
- Preserve `LocalModelError` mapping and current streaming semantics.
- Keep the diff small and aligned with the current package boundaries.

## Non-Goals

- No public API change for passing structured messages.
- No new dependency or dependency replacement.
- No patching of `mlx-swift-lm`.
- No change to the truthfulness instruction behavior in this task.
- No attempt to make base models behave like instruction-tuned chat models.

## Current Behavior

Today the package composes a single prompt string, wraps it with the internal
truthfulness instruction, creates `UserInput(prompt:)`, and hands preparation to
`mlx-swift-lm`.

That means even a single prompt follows the dependency's chat path first. When
the tokenizer has no chat template, `mlx-swift-lm` catches
`TokenizerError.missingChatTemplate`, prints a warning, joins message contents,
and tokenizes the resulting plain text.

## Proposed Approach

Introduce an internal prompt-mode decision before input preparation.

### Internal Types

Add a new internal enum:

```swift
enum PromptPreparationMode: Sendable {
    case chatTemplateAvailable
    case plainText
}
```

Add a new internal reader responsible only for model-directory capability
detection:

```swift
struct PromptPreparationModeReader {
    func mode(for modelDirectory: URL) -> PromptPreparationMode
}
```

This reader will inspect model metadata on disk and determine whether the model
supports chat templating.

### Detection Rules

Return `.chatTemplateAvailable` when either of the following is true:

- `chat_template.json` exists in the model directory
- `tokenizer_config.json` contains a non-empty `chat_template` entry

Otherwise return `.plainText`.

If metadata files are missing or unreadable, default to `.plainText`. This is
intentional. Prompt mode is a capability check, not a hard validation step.

## Architecture

### PromptPreparationModeReader

Responsibility:

- inspect model-directory metadata
- detect chat-template capability
- return an internal enum

Must not:

- know about `MLX`
- load models
- build `UserInput`
- perform tokenization

### MLXGenerator

Responsibility:

- resolve prompt-preparation mode
- prepare `LMInput` using the correct path
- continue enforcing token-budget validation on the prepared input

Behavior:

- `.chatTemplateAvailable`: keep the current path using `UserInput(prompt:)`
  and `model.container.prepare(input:)`
- `.plainText`: directly encode the final prompt text without calling the
  dependency path that attempts chat-template application first

### TruthfulnessPromptBuilder

No behavior change in this task.

The truthfulness instruction layer remains a string-level transformation applied
before prompt preparation. In plain-text mode it remains part of the encoded
text prompt. In chat-template mode it continues to behave exactly as it does
today.

## Data Flow

### Chat-template mode

1. Caller invokes `generate(prompt:)` or `stream(prompt:)`.
2. Package composes the final prompt string with the internal truthfulness layer.
3. `MLXGenerator` resolves `.chatTemplateAvailable`.
4. Package creates `UserInput(prompt:)`.
5. Package calls `model.container.prepare(input:)`.
6. Prepared token count is validated against the available context window.
7. Generation proceeds unchanged.

### Plain-text mode

1. Caller invokes `generate(prompt:)` or `stream(prompt:)`.
2. Package composes the final prompt string with the internal truthfulness layer.
3. `MLXGenerator` resolves `.plainText`.
4. Package directly encodes the final prompt string to tokens.
5. Package builds `LMInput` from those tokens.
6. Prepared token count is validated against the available context window.
7. Generation proceeds without entering the dependency's chat-template fallback path.

## Direct Encoding Path

The recommended implementation is to obtain the tokenizer from the loaded model
container and encode the final prompt string directly for plain-text mode.

Requirements for this path:

- it must not call `tokenizer.applyChatTemplate(...)`
- it must use the same tokenizer instance already associated with the loaded model
- it must produce an `LMInput` compatible with the existing generation path
- token-budget validation must use the resulting encoded token count

If direct tokenizer access proves impossible from the current loaded-model
abstraction, the task must stop and be redesigned before adding duplicate prompt
preparation logic from the dependency.

## Error Handling

Missing chat-template metadata is not a `LocalModelError`.

Expected behavior:

- no new public error case
- no failure for plain-text-capable models lacking chat metadata
- metadata parse failures fall back to `.plainText`

Real failures remain unchanged:

- invalid model path
- model load failure
- context-window overflow
- inference failure

## Logging Policy

Absence of chat-template metadata should not produce a user-facing warning once
the package intentionally selects plain-text mode.

Preferred policy for this task:

- no public log output for expected plain-text mode
- no bridging of this capability difference into `LocalModelError`

If future debugging needs arise, any log should be package-controlled and
debug-only, not emitted by dependency fallback.

## Testing Strategy

Add deterministic tests for two layers.

### Metadata detection tests

- returns `.plainText` when both `chat_template.json` and tokenizer-config
  `chat_template` are absent
- returns `.chatTemplateAvailable` when `chat_template.json` exists
- returns `.chatTemplateAvailable` when tokenizer-config `chat_template` exists
- returns `.plainText` when tokenizer metadata is unreadable or malformed

Use temporary directories and small JSON fixtures only.

### Generator path-selection tests

- plain-text mode uses direct encoding and does not enter the chat-template
  preparation path
- chat-template mode keeps the existing preparation path
- token-budget validation still evaluates the actual prepared token count
- one-shot and streaming generation behavior remain unchanged from the public
  API perspective

These tests should use fakes or spies rather than real model weights.

## Risks

### Tokenizer access risk

The main technical risk is whether the current loaded-model abstraction exposes
enough access to the tokenizer for a clean direct-encode path.

Mitigation:

- validate this before deeper implementation
- avoid reimplementing dependency internals unless explicitly approved

### Behavior drift between modes

Plain-text and chat-template modes may tokenize the same visible prompt
differently. That is expected because the modes serve different model
capabilities.

Mitigation:

- keep the distinction explicit and internal
- test both paths separately
- avoid claiming semantic equivalence between base and instruct models

## Rollout Scope

This task is intentionally narrow:

- add internal mode detection
- route prompt preparation by mode
- add focused tests
- keep public API unchanged

Follow-up work, if later approved, can build on this:

- expose structured `system` and `user` roles in the public API
- support custom chat templates
- move truthfulness instructions into a dedicated `system` role for chat-aware models

## Acceptance Criteria

The task is complete when all of the following are true:

- models without chat-template metadata use intentional plain-text prompting
- host applications no longer receive the dependency warning for that case
- models with chat-template metadata continue using the current chat-aware path
- public API remains unchanged
- `LocalModelError` and `LocalModelStreamEvent` behavior remain unchanged
- deterministic tests cover both prompt-preparation modes
