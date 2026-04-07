import Foundation

/// Configuration for loading and running a local model.
public struct LocalModelConfiguration: Sendable, Equatable {
    /// The filesystem location of the local MLX-compatible model directory.
    public var modelPath: URL
    /// An optional manual context-window limit used when model metadata is missing or unreliable.
    public var contextWindowOverride: Int?
    /// Default generation settings applied when a request does not provide overrides.
    public var defaultGenerationOptions: GenerationOptions

    /// Creates a configuration for a local model client.
    ///
    /// - Parameters:
    ///   - modelPath: The filesystem location of the local MLX-compatible model directory.
    ///   - contextWindowOverride: An optional manual context-window limit used when model metadata is missing or unreliable.
    ///   - defaultGenerationOptions: Default generation settings applied when a request does not provide overrides.
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
