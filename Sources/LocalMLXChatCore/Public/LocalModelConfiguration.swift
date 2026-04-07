import Foundation

public struct LocalModelConfiguration: Sendable, Equatable {
    public var modelPath: URL
    public var contextWindowOverride: Int?
    public var defaultGenerationOptions: GenerationOptions

    public init(
        modelPath: URL,
        contextWindowOverride: Int? = nil,
        defaultGenerationOptions: GenerationOptions = GenerationOptions(
            maxTokens: 256,
            temperature: 0.7,
            topP: 1.0,
            seed: nil
        )
    ) {
        self.modelPath = modelPath
        self.contextWindowOverride = contextWindowOverride
        self.defaultGenerationOptions = defaultGenerationOptions
    }
}
