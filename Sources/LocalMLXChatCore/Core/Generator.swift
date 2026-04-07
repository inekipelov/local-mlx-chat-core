import Foundation

protocol Generating: Sendable {
    func generate(
        using model: any LoadedModel,
        prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration
    ) async throws -> String
    func stream(
        using model: any LoadedModel,
        prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration
    ) throws -> AsyncThrowingStream<String, Error>
}
