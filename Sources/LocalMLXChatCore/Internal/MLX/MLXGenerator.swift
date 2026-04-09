import Foundation
import MLX
import MLXLMCommon

protocol PromptPreparingLoadedModel: LoadedModel {
    var modelDirectory: URL { get }
    func prepareChatInput(prompt: String) async throws -> LMInput
    func encodePlainTextPrompt(_ prompt: String) async -> [Int]
}

protocol PlainTextLMInputBuilding: Sendable {
    func makeInput(tokens: [Int]) throws -> LMInput
}

struct DefaultPlainTextLMInputBuilder: PlainTextLMInputBuilding {
    func makeInput(tokens: [Int]) throws -> LMInput {
        LMInput(tokens: MLXArray(tokens))
    }
}

struct MLXLoadedModel: PromptPreparingLoadedModel {
    let container: ModelContainer
    let modelDirectory: URL

    func prepareChatInput(prompt: String) async throws -> LMInput {
        try await container.prepare(input: UserInput(prompt: prompt))
    }

    func encodePlainTextPrompt(_ prompt: String) async -> [Int] {
        await container.encode(prompt)
    }
}

struct MLXModelEngine: ModelEngine {
    func loadModel(at path: URL) async throws -> any LoadedModel {
        let container = try await MLXLMCommon.loadModelContainer(directory: path)
        return MLXLoadedModel(container: container, modelDirectory: path)
    }
}

struct MLXGenerator: Generating {
    private let metadataReader: ContextWindowMetadataReader
    private let promptPreparationModeReader: PromptPreparationModeReader
    private let tokenBudgetValidator: TokenBudgetValidator
    private let plainTextInputBuilder: any PlainTextLMInputBuilding

    init(
        metadataReader: ContextWindowMetadataReader = ContextWindowMetadataReader(),
        promptPreparationModeReader: PromptPreparationModeReader = PromptPreparationModeReader(),
        tokenBudgetValidator: TokenBudgetValidator = TokenBudgetValidator(),
        plainTextInputBuilder: any PlainTextLMInputBuilding = DefaultPlainTextLMInputBuilder()
    ) {
        self.metadataReader = metadataReader
        self.promptPreparationModeReader = promptPreparationModeReader
        self.tokenBudgetValidator = tokenBudgetValidator
        self.plainTextInputBuilder = plainTextInputBuilder
    }

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

    func preparedInput(
        for prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration,
        model: any PromptPreparingLoadedModel
    ) async throws -> LMInput {
        let prepared: LMInput
        switch promptPreparationModeReader.mode(for: model.modelDirectory) {
        case .chatTemplateAvailable:
            prepared = try await model.prepareChatInput(prompt: prompt)
        case .plainText:
            let tokens = await model.encodePlainTextPrompt(prompt)
            prepared = try plainTextInputBuilder.makeInput(tokens: tokens)
        }
        let availableContextWindow = metadataReader.effectiveContextWindow(modelDirectory: model.modelDirectory)

        try tokenBudgetValidator.validate(
            promptTokenCount: prepared.text.tokens.size,
            requestedOutputTokens: options.maxTokens,
            availableContextWindow: availableContextWindow
        )

        return prepared
    }
}
