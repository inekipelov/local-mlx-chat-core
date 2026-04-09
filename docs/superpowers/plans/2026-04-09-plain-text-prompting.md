# Plain-Text Prompting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add internal prompt-mode detection so models without chat-template metadata use an intentional plain-text encode path without changing the public API.

**Architecture:** Add a focused metadata reader that decides whether a model supports chat templating, then teach `MLXGenerator` to branch between the existing `UserInput(prompt:)` path and a direct `ModelContainer.encode(_:)` path. Cover the behavior with deterministic Swift Testing tests for both metadata detection and generator routing.

**Tech Stack:** Swift 6.1, Swift Package Manager, Swift Testing, MLXLMCommon

---

### Task 1: Add failing tests for prompt-mode metadata detection

**Files:**
- Create: `Tests/LocalMLXChatCoreTests/PromptPreparationModeReaderTests.swift`
- Reference: `Sources/LocalMLXChatCore/Internal/ContextWindowMetadataReader.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import LocalMLXChatCore

struct PromptPreparationModeReaderTests {
    @Test func returnsPlainTextWhenNoTemplateMetadataExists() throws
    @Test func returnsChatTemplateAvailableWhenChatTemplateFileExists() throws
    @Test func returnsChatTemplateAvailableWhenTokenizerConfigContainsTemplate() throws
    @Test func returnsPlainTextWhenTokenizerConfigIsMalformed() throws
}
```

- [ ] **Step 2: Run the test target to verify it fails**

Run: `swift test --filter PromptPreparationModeReaderTests`
Expected: FAIL because `PromptPreparationModeReader` and `PromptPreparationMode` do not exist yet.

- [ ] **Step 3: Add the minimal implementation**

```swift
enum PromptPreparationMode: Sendable {
    case chatTemplateAvailable
    case plainText
}

struct PromptPreparationModeReader: Sendable {
    func mode(for modelDirectory: URL) -> PromptPreparationMode { ... }
}
```

- [ ] **Step 4: Re-run the focused tests**

Run: `swift test --filter PromptPreparationModeReaderTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalMLXChatCore/Internal/PromptPreparationModeReader.swift Tests/LocalMLXChatCoreTests/PromptPreparationModeReaderTests.swift
git commit -m "test: add prompt preparation mode reader"
```

### Task 2: Add failing generator tests for plain-text routing

**Files:**
- Create: `Tests/LocalMLXChatCoreTests/MLXGeneratorTests.swift`
- Reference: `Sources/LocalMLXChatCore/Internal/MLX/MLXGenerator.swift`
- Reference: `.build/checkouts/mlx-swift-lm/Libraries/MLXLMCommon/LanguageModel.swift`

- [ ] **Step 1: Write the failing generator tests**

```swift
import Foundation
import Testing
import MLX
import MLXLMCommon
@testable import LocalMLXChatCore

struct MLXGeneratorTests {
    @Test func plainTextModeUsesDirectEncodePath() async throws
    @Test func chatTemplateModeUsesPreparedInputPath() async throws
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `swift test --filter MLXGeneratorTests`
Expected: FAIL because `MLXGenerator` is not injectable for prompt-mode testing yet.

- [ ] **Step 3: Add the minimal generator seams**

```swift
struct MLXGenerator: Generating {
    init(
        promptPreparationModeReader: PromptPreparationModeReader = PromptPreparationModeReader(),
        inputPreparer: MLXInputPreparing = MLXInputPreparer(),
        tokenBudgetValidator: TokenBudgetValidator = TokenBudgetValidator(),
        metadataReader: ContextWindowMetadataReader = ContextWindowMetadataReader()
    ) { ... }
}
```

- [ ] **Step 4: Re-run the focused generator tests**

Run: `swift test --filter MLXGeneratorTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalMLXChatCore/Internal/MLX/MLXGenerator.swift Tests/LocalMLXChatCoreTests/MLXGeneratorTests.swift
git commit -m "test: cover prompt preparation routing"
```

### Task 3: Route plain-text models through direct encoding

**Files:**
- Modify: `Sources/LocalMLXChatCore/Internal/MLX/MLXGenerator.swift`
- Create: `Sources/LocalMLXChatCore/Internal/PromptPreparationModeReader.swift`

- [ ] **Step 1: Implement prompt-mode detection**

```swift
func mode(for modelDirectory: URL) -> PromptPreparationMode {
    if FileManager.default.fileExists(atPath: modelDirectory.appending(path: "chat_template.json").path()) {
        return .chatTemplateAvailable
    }
    // parse tokenizer_config.json and inspect chat_template
    return .plainText
}
```

- [ ] **Step 2: Implement the direct plain-text encode path**

```swift
let mode = promptPreparationModeReader.mode(for: model.modelDirectory)
switch mode {
case .chatTemplateAvailable:
    return try await inputPreparer.prepareChatPrompt(prompt, using: model.container)
case .plainText:
    return await inputPreparer.preparePlainTextPrompt(prompt, using: model.container)
}
```

- [ ] **Step 3: Keep token-budget validation on the actual prepared input**

```swift
try tokenBudgetValidator.validate(
    promptTokenCount: prepared.text.tokens.size,
    requestedOutputTokens: options.maxTokens,
    availableContextWindow: availableContextWindow
)
```

- [ ] **Step 4: Run targeted tests**

Run: `swift test --filter PromptPreparationModeReaderTests`
Expected: PASS

Run: `swift test --filter MLXGeneratorTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalMLXChatCore/Internal/PromptPreparationModeReader.swift Sources/LocalMLXChatCore/Internal/MLX/MLXGenerator.swift Tests/LocalMLXChatCoreTests/PromptPreparationModeReaderTests.swift Tests/LocalMLXChatCoreTests/MLXGeneratorTests.swift
git commit -m "feat: add plain-text prompt preparation mode"
```

### Task 4: Run broader verification and adjust any affected tests

**Files:**
- Modify if needed: `Tests/LocalMLXChatCoreTests/ContextWindowGuardTests.swift`
- Modify if needed: `Tests/LocalMLXChatCoreTests/LLMServiceTests.swift`

- [ ] **Step 1: Run the package test suite**

Run: `swift test`
Expected: PASS

- [ ] **Step 2: If failures appear, make the smallest corrective edits**

```swift
// Keep public API expectations unchanged.
// Only adjust tests that now need shared helpers or explicit imports.
```

- [ ] **Step 3: Re-run the full suite**

Run: `swift test`
Expected: PASS

- [ ] **Step 4: Commit final verification fixes if needed**

```bash
git add Tests/LocalMLXChatCoreTests
git commit -m "test: stabilize plain-text prompting coverage"
```
