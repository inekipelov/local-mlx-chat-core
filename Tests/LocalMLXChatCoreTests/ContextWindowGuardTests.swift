import Foundation
import Testing
@testable import LocalMLXChatCore

struct ContextWindowGuardTests {
    @Test func metadataReaderLoadsMaxPositionEmbeddingsFromConfig() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeConfig(["max_position_embeddings": 8192], to: directory)

        let reader = ContextWindowMetadataReader()

        let limit = reader.maxPositionEmbeddings(from: directory)

        #expect(limit == 8192)
    }

    @Test func metadataReaderReturnsNilWhenFieldMissing() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeConfig(["model_type": "llama"], to: directory)

        let reader = ContextWindowMetadataReader()

        let limit = reader.effectiveContextWindow(modelDirectory: directory)

        #expect(limit == nil)
    }

    @Test func validatorThrowsWhenPromptAlreadyExceedsContextWindow() throws {
        let validator = TokenBudgetValidator()
        let error = LocalModelError.contextWindowExceeded(
            promptTokens: 1024,
            requestedOutputTokens: 64,
            availableContextWindow: 1024
        )

        #expect(throws: error) {
            try validator.validate(
                promptTokenCount: 1024,
                requestedOutputTokens: 64,
                availableContextWindow: 1024
            )
        }
    }

    @Test func validatorThrowsWhenPromptAndOutputExceedContextWindow() throws {
        let validator = TokenBudgetValidator()
        let error = LocalModelError.contextWindowExceeded(
            promptTokens: 900,
            requestedOutputTokens: 200,
            availableContextWindow: 1024
        )

        #expect(throws: error) {
            try validator.validate(
                promptTokenCount: 900,
                requestedOutputTokens: 200,
                availableContextWindow: 1024
            )
        }
    }

    @Test func validatorAllowsExactFitBoundary() throws {
        let validator = TokenBudgetValidator()

        try validator.validate(
            promptTokenCount: 900,
            requestedOutputTokens: 124,
            availableContextWindow: 1024
        )
    }

    @Test func validatorSkipsWhenContextWindowUnknown() throws {
        let validator = TokenBudgetValidator()

        try validator.validate(
            promptTokenCount: 10_000,
            requestedOutputTokens: 10_000,
            availableContextWindow: nil
        )
    }
}

private func writeConfig(_ object: [String: Any], to directory: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
    try data.write(to: directory.appending(path: "config.json"))
}

private func temporaryModelDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
