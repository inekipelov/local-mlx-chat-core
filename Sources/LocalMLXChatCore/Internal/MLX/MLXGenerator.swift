import Foundation
import MLX
import MLXLMCommon

struct MLXLoadedModel: LoadedModel {
    let container: ModelContainer
    let modelDirectory: URL
}

struct MLXModelEngine: ModelEngine {
    func loadModel(at path: URL) async throws -> any LoadedModel {
        let container = try await MLXLMCommon.loadModelContainer(directory: path)
        return MLXLoadedModel(container: container, modelDirectory: path)
    }
}

struct MLXGenerator: Generating {
    private let metadataReader = ContextWindowMetadataReader()
    private let tokenBudgetValidator = TokenBudgetValidator()

    func generate(
        using model: any LoadedModel,
        prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration
    ) async throws -> String {
        let stream = try stream(using: model, prompt: prompt, options: options, configuration: configuration)
        var output = ""
        for try await chunk in stream {
            output += chunk
        }
        return output
    }

    func stream(
        using model: any LoadedModel,
        prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration
    ) throws -> AsyncThrowingStream<String, Error> {
        guard let model = model as? MLXLoadedModel else {
            throw LocalModelError.inferenceFailed("Unsupported loaded model type")
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let prepared = try await preparedInput(
                        for: prompt,
                        options: options,
                        configuration: configuration,
                        model: model
                    )
                    if let seed = options.seed {
                        MLX.seed(seed)
                    }
                    let parameters = GenerateParameters(
                        maxTokens: options.maxTokens,
                        temperature: Float(options.temperature),
                        topP: Float(options.topP)
                    )
                    let output = try await model.container.generate(input: prepared, parameters: parameters)
                    for await generation in output {
                        if let chunk = generation.chunk, !chunk.isEmpty {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func preparedInput(
        for prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration,
        model: MLXLoadedModel
    ) async throws -> LMInput {
        let input = UserInput(prompt: prompt)
        let prepared = try await model.container.prepare(input: input)
        let availableContextWindow = metadataReader.effectiveContextWindow(
            for: configuration,
            modelDirectory: model.modelDirectory
        )

        try tokenBudgetValidator.validate(
            promptTokenCount: prepared.text.tokens.size,
            requestedOutputTokens: options.maxTokens,
            availableContextWindow: availableContextWindow
        )

        return prepared
    }
}
