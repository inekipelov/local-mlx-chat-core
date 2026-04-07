import Foundation
import Testing
@testable import LocalMLXChatCore

struct GenerationOptionsTests {
    @Test func resolvedOptionsPreferCallOverrides() {
        let configuration = LocalModelConfiguration(
            modelPath: URL(filePath: "/tmp/model"),
            defaultGenerationOptions: GenerationOptions(maxTokens: 512, temperature: 0.7, topP: 0.9, seed: 42)
        )
        let overrides = GenerationOptions(maxTokens: 64, temperature: nil, topP: 0.8, seed: nil)

        let resolved = overrides.resolved(using: configuration)

        #expect(resolved.maxTokens == 64)
        #expect(resolved.temperature == 0.7)
        #expect(resolved.topP == 0.8)
        #expect(resolved.seed == 42)
    }

    @Test func configurationDefaultsAreDeterministic() {
        let configuration = LocalModelConfiguration(modelPath: URL(filePath: "/tmp/model"))

        #expect(configuration.defaultGenerationOptions.maxTokens == 256)
        #expect(configuration.defaultGenerationOptions.temperature == 0.7)
        #expect(configuration.defaultGenerationOptions.topP == 1.0)
        #expect(configuration.defaultGenerationOptions.seed == nil)
    }
}
