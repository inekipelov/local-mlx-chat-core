import Foundation

/// A high-level client for local MLX-backed text generation.
public final class LocalModelClient: Sendable {
    private let configuration: LocalModelConfiguration
    private let modelRepository: ModelRepository
    private let generator: any Generating
    private let modelStore: ModelStore

    /// Creates a client configured to load and run a local model from disk.
    ///
    /// - Parameter configuration: The model location and default generation settings to use for requests.
    public init(configuration: LocalModelConfiguration) {
        self.configuration = configuration
        self.modelRepository = ModelRepository()
        self.generator = TruthfulnessPromptingGenerator(base: MLXGenerator())
        self.modelStore = ModelStore()
    }

    init(
        configuration: LocalModelConfiguration,
        modelRepository: ModelRepository,
        generator: any Generating,
        modelStore: ModelStore = ModelStore()
    ) {
        self.configuration = configuration
        self.modelRepository = modelRepository
        self.generator = TruthfulnessPromptingGenerator(base: generator)
        self.modelStore = modelStore
    }

    /// Generates a complete response for a prompt.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt to send to the local model.
    ///   - options: Optional per-request generation overrides. Unspecified values fall back to the client configuration.
    /// - Returns: The full generated response text.
    /// - Throws: ``LocalModelError`` when model loading, validation, or inference fails.
    public func generate(prompt: String, options: GenerationOptions? = nil) async throws -> String {
        let resolvedOptions = (options ?? GenerationOptions()).resolved(using: configuration)
        let model = try await modelStore.model(configuration: configuration, repository: modelRepository)

        do {
            return try await generator.generate(
                using: model,
                prompt: prompt,
                options: resolvedOptions,
                configuration: configuration
            )
        } catch {
            throw LocalModelError.mapInferenceError(error)
        }
    }

    /// Streams response events for a prompt as incremental chunks, completion, or typed failures.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt to send to the local model.
    ///   - options: Optional per-request generation overrides. Unspecified values fall back to the client configuration.
    /// - Returns: An asynchronous stream of ``LocalModelStreamEvent`` values.
    public func stream(prompt: String, options: GenerationOptions? = nil) -> AsyncStream<LocalModelStreamEvent> {
        let resolvedOptions = (options ?? GenerationOptions()).resolved(using: configuration)
        let modelStore = self.modelStore
        let configuration = self.configuration
        let modelRepository = self.modelRepository
        let generator = self.generator

        return AsyncStream { continuation in
            let task = Task {
                do {
                    let model = try await modelStore.model(configuration: configuration, repository: modelRepository)
                    let stream = try generator.stream(
                        using: model,
                        prompt: prompt,
                        options: resolvedOptions,
                        configuration: configuration
                    )
                    for try await chunk in stream {
                        continuation.yield(.chunk(chunk))
                    }
                    continuation.yield(.finished)
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(LocalModelError.mapInferenceError(error)))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
