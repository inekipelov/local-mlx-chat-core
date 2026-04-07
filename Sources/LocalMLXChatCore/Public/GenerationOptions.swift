import Foundation

public struct GenerationOptions: Sendable, Equatable {
    public var maxTokens: Int?
    public var temperature: Double?
    public var topP: Double?
    public var seed: UInt64?

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

    func resolved(using configuration: LocalModelConfiguration) -> ResolvedGenerationOptions {
        ResolvedGenerationOptions(
            maxTokens: maxTokens ?? configuration.defaultGenerationOptions.maxTokens ?? 256,
            temperature: temperature ?? configuration.defaultGenerationOptions.temperature ?? 0.7,
            topP: topP ?? configuration.defaultGenerationOptions.topP ?? 1.0,
            seed: seed ?? configuration.defaultGenerationOptions.seed
        )
    }
}

struct ResolvedGenerationOptions: Sendable, Equatable {
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let seed: UInt64?
}
