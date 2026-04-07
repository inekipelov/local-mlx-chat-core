# Review Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix high-impact review findings around MLX prompt handling, actor reentrancy, and concurrency/test coverage in `LocalMLXChatCore`.

**Architecture:** Keep one public facade (`LLMService`) and harden internals. Remove model-specific prompt templating from the default path, deduplicate model loading inside `ModelStore`, and add tests that lock in concurrency-safe behavior and error mapping. Changes are intentionally small, local, and backward-compatible at the API level.

**Tech Stack:** Swift 6, Swift Testing, MLX Swift (`MLX`, `MLXLMCommon`, `MLXLMTokenizers`)

---

### Task 1: Prompt Path Cleanup and Public Concurrency Annotation

**Files:**
- Modify: `Sources/LocalMLXChatCore/Core/PromptBuilder.swift`
- Modify: `Sources/LocalMLXChatCore/Public/LLMService.swift`
- Test: `Tests/LocalMLXChatCoreTests/PromptBuilderTests.swift`

- [ ] **Step 1: Write failing prompt tests for raw-pass-through behavior**

```swift
import Testing
@testable import LocalMLXChatCore

struct PromptBuilderTests {
    @Test func promptBuilderPassesPromptThroughUnchanged() {
        let builder = PromptBuilder()
        let prompt = builder.makePrompt(from: "Tell me a joke")
        #expect(prompt == "Tell me a joke")
    }

    @Test func promptBuilderPreservesWhitespaceInsidePrompt() {
        let builder = PromptBuilder()
        let prompt = builder.makePrompt(from: "Line 1\n  Line 2")
        #expect(prompt == "Line 1\n  Line 2")
    }
}
```

- [ ] **Step 2: Run prompt tests to verify failure before implementation**

Run: `swift test --filter PromptBuilderTests`
Expected: FAIL because current builder injects chat template.

- [ ] **Step 3: Implement minimal prompt cleanup and remove unchecked sendable**

```swift
// PromptBuilder.swift
import Foundation

struct PromptBuilder {
    func makePrompt(from userPrompt: String) -> String {
        userPrompt
    }
}

// LLMService.swift
import Foundation

public final class LLMService {
    // existing implementation unchanged
}
```

- [ ] **Step 4: Re-run prompt tests to verify pass**

Run: `swift test --filter PromptBuilderTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalMLXChatCore/Core/PromptBuilder.swift Sources/LocalMLXChatCore/Public/LLMService.swift Tests/LocalMLXChatCoreTests/PromptBuilderTests.swift
git commit -m "fix: remove hardcoded prompt template and unchecked sendable"
```

### Task 2: Actor Reentrancy Hardening in ModelStore

**Files:**
- Modify: `Sources/LocalMLXChatCore/Internal/ModelStore.swift`
- Test: `Tests/LocalMLXChatCoreTests/LLMServiceTests.swift`

- [ ] **Step 1: Add failing concurrency test for deduplicated model loading**

```swift
@Test func concurrentGenerateCallsReuseSingleModelLoad() async throws {
    let directory = try temporaryModelDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let counter = LoadCounter()
    let engine = CountingEngine(counter: counter, loadedModel: MockLoadedModel())

    let service = LLMService(
        configuration: LLMConfiguration(modelPath: directory),
        modelLoader: ModelLoader(engine: engine),
        promptBuilder: PromptBuilder(),
        generator: MockGenerator(result: .success("ok"))
    )

    async let first = service.generate(prompt: "A")
    async let second = service.generate(prompt: "B")
    _ = try await (first, second)

    let loadCount = await counter.value
    #expect(loadCount == 1)
}
```

- [ ] **Step 2: Run targeted test to verify failure before fix**

Run: `swift test --filter concurrentGenerateCallsReuseSingleModelLoad`
Expected: FAIL with `loadCount > 1` on current reentrant path.

- [ ] **Step 3: Implement in-flight load deduplication in actor**

```swift
import Foundation

actor ModelStore {
    private var cachedModel: (any LoadedModel)?
    private var inFlightLoad: Task<any LoadedModel, Error>?

    func model(configuration: LLMConfiguration, loader: ModelLoader) async throws -> any LoadedModel {
        if let cachedModel {
            return cachedModel
        }
        if let inFlightLoad {
            return try await inFlightLoad.value
        }

        let loadTask = Task {
            try await loader.loadModel(using: configuration)
        }
        inFlightLoad = loadTask

        do {
            let loaded = try await loadTask.value
            cachedModel = loaded
            inFlightLoad = nil
            return loaded
        } catch {
            inFlightLoad = nil
            throw error
        }
    }
}
```

- [ ] **Step 4: Re-run targeted concurrency test**

Run: `swift test --filter concurrentGenerateCallsReuseSingleModelLoad`
Expected: PASS with exactly one model load.

- [ ] **Step 5: Commit**

```bash
git add Sources/LocalMLXChatCore/Internal/ModelStore.swift Tests/LocalMLXChatCoreTests/LLMServiceTests.swift
git commit -m "fix: prevent duplicate model loads in actor reentrancy"
```

### Task 3: Streaming Error Mapping Test Coverage

**Files:**
- Modify: `Tests/LocalMLXChatCoreTests/LLMServiceTests.swift`

- [ ] **Step 1: Add failing stream error mapping test**

```swift
@Test func streamMapsGeneratorErrorsToLLMError() async throws {
    let directory = try temporaryModelDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let service = LLMService(
        configuration: LLMConfiguration(modelPath: directory),
        modelLoader: ModelLoader(engine: MockEngine(loadResult: .success(MockLoadedModel()))),
        promptBuilder: PromptBuilder(),
        generator: MockGenerator(streamResult: .failure(MockFailure.inference))
    )

    let output = try service.stream(prompt: "Hi")

    await #expect(throws: LLMError.inferenceFailed("mock-inference")) {
        for try await _ in output {
            Issue.record("No chunks expected")
        }
    }
}
```

- [ ] **Step 2: Run targeted stream test to verify current behavior**

Run: `swift test --filter streamMapsGeneratorErrorsToLLMError`
Expected: PASS once mapping is confirmed; if not, adjust service mapping path.

- [ ] **Step 3: Keep implementation minimal**

```swift
// No production change expected if mapping already works.
// Retain existing mapping:
continuation.finish(throwing: LLMError.mapInferenceError(error))
```

- [ ] **Step 4: Re-run LLMService test suite**

Run: `swift test --filter LLMServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Tests/LocalMLXChatCoreTests/LLMServiceTests.swift
git commit -m "test: cover stream error mapping and concurrent load path"
```

### Task 4: Full Verification and README Consistency Check

**Files:**
- Modify: `README.md` (only if API wording needs alignment)

- [ ] **Step 1: Run full package tests**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 2: Build package in debug**

Run: `swift build`
Expected: successful build with no new warnings introduced by fixes.

- [ ] **Step 3: Verify README does not promise hardcoded prompt template behavior**

```markdown
Check that README usage describes prompt-first API without claiming specific template tokens.
```

- [ ] **Step 4: If README changes needed, apply minimal wording fix and verify tests again**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: align README with prompt pass-through behavior"
```
