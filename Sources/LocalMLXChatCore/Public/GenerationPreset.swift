import Foundation

/// A curated generation setup for common local inference use cases.
public enum GenerationPreset: Sendable, Equatable, CaseIterable {
    /// Lower-latency output with shorter responses and less sampling variance.
    case fast
    /// General-purpose output tuned for typical app-facing conversations.
    case balanced
    /// More conservative sampling for tasks where consistency matters more than variety.
    case precise

    /// The concrete generation settings represented by this preset.
    public var options: GenerationOptions {
        switch self {
        case .fast:
            GenerationOptions(maxTokens: 128, temperature: 0.6, topP: 0.9, seed: nil)
        case .balanced:
            GenerationOptions(maxTokens: 256, temperature: 0.7, topP: 0.95, seed: nil)
        case .precise:
            GenerationOptions(maxTokens: 256, temperature: 0.2, topP: 0.9, seed: nil)
        }
    }
}
