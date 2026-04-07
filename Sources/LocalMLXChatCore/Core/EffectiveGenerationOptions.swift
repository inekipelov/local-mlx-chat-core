import Foundation

struct EffectiveGenerationOptions: Sendable, Equatable {
    let maxTokens: Int
    let temperature: Double
    let topP: Double
    let seed: UInt64?
}
