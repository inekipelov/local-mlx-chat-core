import Foundation

/// Optional per-request generation overrides.
///
/// Any property left as `nil` inherits its value from ``LocalModelConfiguration/generationPreset``.
public struct GenerationOptions: Sendable, Equatable {
    /// The maximum number of tokens to generate.
    public var maxTokens: Int?
    /// The sampling temperature to use during generation.
    public var temperature: Double?
    /// The nucleus sampling value to use during generation.
    public var topP: Double?
    /// An optional deterministic seed for repeatable sampling.
    public var seed: UInt64?

    /// Creates a set of optional generation overrides for a single request.
    ///
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens to generate.
    ///   - temperature: The sampling temperature to use during generation.
    ///   - topP: The nucleus sampling value to use during generation.
    ///   - seed: An optional deterministic seed for repeatable sampling.
    public init(
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        seed: UInt64? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.seed = seed
    }

    func resolved(using configuration: LocalModelConfiguration) -> EffectiveGenerationOptions {
        let presetOptions = configuration.generationPreset.options

        return EffectiveGenerationOptions(
            maxTokens: maxTokens ?? presetOptions.maxTokens ?? 256,
            temperature: temperature ?? presetOptions.temperature ?? 0.7,
            topP: topP ?? presetOptions.topP ?? 0.95,
            seed: seed ?? presetOptions.seed
        )
    }
}
