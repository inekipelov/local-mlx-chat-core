import Foundation
import Testing
@testable import LocalMLXChatCore

struct PromptPreparationModeReaderTests {
    @Test func returnsPlainTextWhenNoTemplateMetadataExists() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .plainText)
    }

    @Test func returnsChatTemplateAvailableWhenChatTemplateFileExists() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeChatTemplateJSON(["chat_template": "{{ messages }}"], to: directory)

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .chatTemplateAvailable)
    }

    @Test func returnsChatTemplateAvailableWhenChatTemplateJinjaFileExists() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{{ messages }}".utf8).write(to: directory.appending(path: "chat_template.jinja"))

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .chatTemplateAvailable)
    }

    @Test func returnsChatTemplateAvailableWhenTokenizerConfigContainsTemplate() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeTokenizerConfig(["chat_template": "{{ messages }}"], to: directory)

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .chatTemplateAvailable)
    }

    @Test func returnsPlainTextWhenTokenizerConfigIsMalformed() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not-json".utf8).write(to: directory.appending(path: "tokenizer_config.json"))

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .plainText)
    }

    @Test func returnsPlainTextWhenTokenizerConfigContainsObjectShapedTemplate() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeTokenizerConfig(["chat_template": ["template": "{{ messages }}"]], to: directory)

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .plainText)
    }

    @Test func returnsPlainTextWhenChatTemplateJSONIsMalformed() throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not-json".utf8).write(to: directory.appending(path: "chat_template.json"))

        let reader = PromptPreparationModeReader()

        #expect(reader.mode(for: directory) == .plainText)
    }
}

private func writeTokenizerConfig(_ object: [String: Any], to directory: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
    try data.write(to: directory.appending(path: "tokenizer_config.json"))
}

private func writeChatTemplateJSON(_ object: [String: Any], to directory: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
    try data.write(to: directory.appending(path: "chat_template.json"))
}

private func temporaryModelDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
