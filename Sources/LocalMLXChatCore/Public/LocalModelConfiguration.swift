import Foundation

/// Configuration for loading and running a local model.
public struct LocalModelConfiguration: Sendable, Equatable {
    /// The filesystem location of the local MLX-compatible model directory.
    public var modelPath: URL
    /// The default generation setup applied when a request does not provide explicit overrides.
    public var generationPreset: GenerationPreset

    /// Creates a configuration for a local model client.
    ///
    /// - Parameters:
    ///   - modelPath: The filesystem location of the local MLX-compatible model directory.
    ///   - generationPreset: The default generation setup to use for requests. Defaults to `.balanced`.
    public init(
        modelPath: URL,
        generationPreset: GenerationPreset = .balanced
    ) {
        self.modelPath = modelPath
        self.generationPreset = generationPreset
    }
}
