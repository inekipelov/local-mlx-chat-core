import Foundation

/// Errors surfaced by the local model client.
public enum LocalModelError: Error, Equatable, Sendable {
    /// The configured model path does not exist or is not a directory.
    case invalidModelPath(String)
    /// The model could not be loaded from the provided path.
    case modelLoadFailed(String)
    /// Generation failed after the model was loaded successfully.
    case inferenceFailed(String)
    /// The prepared prompt and requested output exceed the available context window.
    case contextWindowExceeded(
        /// The number of prompt tokens after model-specific preparation.
        promptTokens: Int,
        /// The number of output tokens requested for generation.
        requestedOutputTokens: Int,
        /// The total available context-window capacity.
        availableContextWindow: Int
    )
}
