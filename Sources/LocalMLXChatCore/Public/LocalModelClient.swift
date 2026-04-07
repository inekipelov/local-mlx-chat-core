import Foundation

public final class LocalModelClient: Sendable {
    private let configuration: LocalModelConfiguration
    private let modelRepository: ModelRepository
    private let generator: any Generating
    private let modelStore: ModelStore

    public init(configuration: LocalModelConfiguration) {
        self.configuration = configuration
        self.modelRepository = ModelRepository()
        self.generator = MLXGenerator()
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
        self.generator = generator
        self.modelStore = modelStore
    }

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
