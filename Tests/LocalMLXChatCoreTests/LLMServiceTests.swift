import Foundation
import Testing
@testable import LocalMLXChatCore

struct LocalModelClientTests {
    @Test func generatePassesPromptToGeneratorAndReturnsText() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let generator = MockGenerator(result: .success("Hello there"))
        let engine = MockEngine(loadResult: .success(MockLoadedModel()))
        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: engine),
            generator: generator
        )

        let output = try await service.generate(prompt: "Hi")
        let recordedPrompts = await generator.recordedPrompts

        #expect(output == "Hello there")
        #expect(recordedPrompts == ["Hi"])
    }

    @Test func streamForwardsTextDeltas() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let engine = MockEngine(loadResult: .success(MockLoadedModel()))
        let stream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("Hel")
            continuation.yield("lo")
            continuation.finish()
        }
        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: engine),
            generator: MockGenerator(streamResult: .success(stream))
        )

        let outputStream = service.stream(prompt: "Hi")
        var chunks: [String] = []
        var sawFinished = false
        for await event in outputStream {
            switch event {
            case .chunk(let chunk):
                chunks.append(chunk)
            case .finished:
                sawFinished = true
            case .failed(let error):
                Issue.record("Unexpected failure: \(error)")
            }
        }

        #expect(chunks == ["Hel", "lo"])
        #expect(sawFinished)
    }

    @Test func invalidModelPathMapsToStructuredError() async {
        let configuration = LocalModelConfiguration(modelPath: URL(filePath: "/tmp/definitely-missing-model"))
        let service = LocalModelClient(
            configuration: configuration,
            modelLoader: ModelLoader(engine: MockEngine(loadResult: .success(MockLoadedModel()))),
            generator: MockGenerator(result: .success("unused"))
        )

        await #expect(throws: LocalModelError.invalidModelPath(configuration.modelPath.path())) {
            try await service.generate(prompt: "Hi")
        }
    }

    @Test func engineLoadFailuresBecomeModelLoadErrors() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: MockEngine(loadResult: .failure(MockFailure.load))),
            generator: MockGenerator(result: .success("unused"))
        )

        await #expect(throws: LocalModelError.modelLoadFailed("mock-load")) {
            try await service.generate(prompt: "Hi")
        }
    }

    @Test func concurrentGenerateCallsReuseSingleModelLoad() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let counter = LoadCounter()
        let engine = CountingEngine(counter: counter, loadedModel: MockLoadedModel())
        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: engine),
            generator: MockGenerator(result: .success("ok"))
        )

        async let first = service.generate(prompt: "A")
        async let second = service.generate(prompt: "B")
        _ = try await (first, second)

        let loadCount = await counter.value
        #expect(loadCount == 1)
    }

    @Test func streamMapsGeneratorErrorsToLocalModelError() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: MockEngine(loadResult: .success(MockLoadedModel()))),
            generator: MockGenerator(streamResult: .failure(MockFailure.inference))
        )

        let output = service.stream(prompt: "Hi")
        var receivedError: LocalModelError?

        for await event in output {
            switch event {
            case .chunk:
                Issue.record("No chunks expected")
            case .finished:
                Issue.record("Unexpected finish event")
            case .failed(let error):
                receivedError = error
            }
        }

        #expect(receivedError == LocalModelError.inferenceFailed("mock-inference"))
    }

    @Test func generatePreservesContextWindowErrors() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let budgetError = LocalModelError.contextWindowExceeded(
            promptTokens: 900,
            requestedOutputTokens: 256,
            availableContextWindow: 1024
        )
        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: MockEngine(loadResult: .success(MockLoadedModel()))),
            generator: MockGenerator(result: .failure(budgetError))
        )

        await #expect(throws: budgetError) {
            try await service.generate(prompt: "Hi")
        }
    }

    @Test func streamPreservesContextWindowErrors() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let budgetError = LocalModelError.contextWindowExceeded(
            promptTokens: 900,
            requestedOutputTokens: 256,
            availableContextWindow: 1024
        )
        let service = LocalModelClient(
            configuration: LocalModelConfiguration(modelPath: directory),
            modelLoader: ModelLoader(engine: MockEngine(loadResult: .success(MockLoadedModel()))),
            generator: MockGenerator(streamResult: .failure(budgetError))
        )

        let output = service.stream(prompt: "Hi")
        var receivedError: LocalModelError?

        for await event in output {
            switch event {
            case .chunk:
                Issue.record("No chunks expected")
            case .finished:
                Issue.record("Unexpected finish event")
            case .failed(let error):
                receivedError = error
            }
        }

        #expect(receivedError == budgetError)
    }
}

private struct MockLoadedModel: LoadedModel {}

private enum MockFailure: Error, LocalizedError {
    case load
    case inference

    var errorDescription: String? {
        switch self {
        case .load:
            return "mock-load"
        case .inference:
            return "mock-inference"
        }
    }
}

private struct MockEngine: ModelEngine {
    let loadResult: Result<any LoadedModel, Error>

    func loadModel(at path: URL) async throws -> any LoadedModel {
        try loadResult.get()
    }
}

private actor LoadCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private struct CountingEngine: ModelEngine {
    let counter: LoadCounter
    let loadedModel: any LoadedModel

    func loadModel(at path: URL) async throws -> any LoadedModel {
        await counter.increment()
        try await Task.sleep(for: .milliseconds(50))
        return loadedModel
    }
}

private final class MockGenerator: Generating {
    let result: Result<String, Error>
    let streamResult: Result<AsyncThrowingStream<String, Error>, Error>
    private let promptRecorder = PromptRecorder()

    init(
        result: Result<String, Error> = .failure(MockFailure.inference),
        streamResult: Result<AsyncThrowingStream<String, Error>, Error> = .failure(MockFailure.inference)
    ) {
        self.result = result
        self.streamResult = streamResult
    }

    func generate(
        using model: any LoadedModel,
        prompt: String,
        options: ResolvedGenerationOptions,
        configuration: LocalModelConfiguration
    ) async throws -> String {
        await promptRecorder.record(prompt)
        return try result.get()
    }

    func stream(
        using model: any LoadedModel,
        prompt: String,
        options: ResolvedGenerationOptions,
        configuration: LocalModelConfiguration
    ) throws -> AsyncThrowingStream<String, Error> {
        Task {
            await promptRecorder.record(prompt)
        }
        return try streamResult.get()
    }

    var recordedPrompts: [String] {
        get async {
            await promptRecorder.prompts
        }
    }
}

private actor PromptRecorder {
    private(set) var prompts: [String] = []

    func record(_ prompt: String) {
        prompts.append(prompt)
    }
}

private func temporaryModelDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
