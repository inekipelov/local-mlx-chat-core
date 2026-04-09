import Foundation
import Testing
@testable import LocalMLXChatCore

struct GenerationOptionsTests {
    @Test func generationPresetsExposeConcreteOptions() {
        #expect(GenerationPreset.fast.options == GenerationOptions(maxTokens: 128, temperature: 0.6, topP: 0.9, seed: nil))
        #expect(GenerationPreset.balanced.options == GenerationOptions(maxTokens: 256, temperature: 0.7, topP: 0.95, seed: nil))
        #expect(GenerationPreset.precise.options == GenerationOptions(maxTokens: 256, temperature: 0.2, topP: 0.9, seed: nil))
    }

    @Test func resolvedOptionsPreferCallOverridesOverPresetDefaults() {
        let configuration = LocalModelConfiguration(
            modelPath: URL(filePath: "/tmp/model"),
            generationPreset: .balanced
        )
        let overrides = GenerationOptions(maxTokens: 64, temperature: nil, topP: 0.8, seed: 42)

        let resolved = overrides.resolved(using: configuration)

        #expect(resolved.maxTokens == 64)
        #expect(resolved.temperature == 0.7)
        #expect(resolved.topP == 0.8)
        #expect(resolved.seed == 42)
    }

    @Test func configurationDefaultsToBalancedPreset() {
        let configuration = LocalModelConfiguration(modelPath: URL(filePath: "/tmp/model"))

        #expect(configuration.generationPreset == .balanced)
        #expect(configuration.generationPreset.options == GenerationOptions(maxTokens: 256, temperature: 0.7, topP: 0.95, seed: nil))
    }

    @Test func configurationEqualityIncludesGenerationPreset() {
        let modelPath = URL(filePath: "/tmp/model")

        #expect(
            LocalModelConfiguration(modelPath: modelPath, generationPreset: .fast) !=
            LocalModelConfiguration(modelPath: modelPath, generationPreset: .precise)
        )
    }
}
