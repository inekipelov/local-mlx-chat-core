import Foundation
import MLX
import MLXLMCommon
import Testing
@testable import LocalMLXChatCore

struct MLXGeneratorTests {
    @Test func plainTextModeUsesDirectEncodePath() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputBuilder = PlainTextLMInputBuilderSpy()
        let generator = MLXGenerator(plainTextInputBuilder: inputBuilder)
        let model = PromptPreparingLoadedModelSpy(modelDirectory: directory)

        await #expect(throws: InputBuilderFailure.intercepted([1, 2, 3])) {
            try await generator.preparedInput(
                for: "Need direct encode",
                options: EffectiveGenerationOptions(maxTokens: 64, temperature: 0.7, topP: 0.95, seed: nil),
                configuration: LocalModelConfiguration(modelPath: directory),
                model: model
            )
        }

        let calls = await model.calls
        #expect(calls == [.encode("Need direct encode")])
        let builtTokens = inputBuilder.recordedTokens
        #expect(builtTokens == [[1, 2, 3]])
    }

    @Test func chatTemplateModeUsesPreparedInputPath() async throws {
        let directory = try temporaryModelDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let templateJSON = try JSONSerialization.data(
            withJSONObject: ["chat_template": "{{ messages }}"],
            options: [.prettyPrinted]
        )
        try templateJSON.write(to: directory.appending(path: "chat_template.json"))

        let generator = MLXGenerator()
        let model = PromptPreparingLoadedModelSpy(
            modelDirectory: directory,
            prepareBehavior: .throwing(.chatPreparationIntercepted)
        )

        await #expect(throws: ModelSpyFailure.chatPreparationIntercepted) {
            try await generator.preparedInput(
                for: "Need chat template",
                options: EffectiveGenerationOptions(maxTokens: 64, temperature: 0.7, topP: 0.95, seed: nil),
                configuration: LocalModelConfiguration(modelPath: directory),
                model: model
            )
        }

        let calls = await model.calls
        #expect(calls == [.prepare("Need chat template")])
    }
}

private struct PromptPreparingLoadedModelSpy: PromptPreparingLoadedModel {
    let modelDirectory: URL
    let prepareBehavior: PrepareBehavior
    private let recorder = CallRecorder()

    init(
        modelDirectory: URL,
        prepareBehavior: PrepareBehavior = .throwing(.unexpectedChatPreparation)
    ) {
        self.modelDirectory = modelDirectory
        self.prepareBehavior = prepareBehavior
    }

    func prepareChatInput(prompt: String) async throws -> LMInput {
        await recorder.record(.prepare(prompt))
        switch prepareBehavior {
        case .throwing(let error):
            throw error
        }
    }

    func encodePlainTextPrompt(_ prompt: String) async -> [Int] {
        await recorder.record(.encode(prompt))
        return [1, 2, 3]
    }

    var calls: [Call] {
        get async { await recorder.calls }
    }
}

private actor CallRecorder {
    private(set) var calls: [Call] = []

    func record(_ call: Call) {
        calls.append(call)
    }
}

private enum Call: Equatable {
    case prepare(String)
    case encode(String)
}

private enum PrepareBehavior: Sendable {
    case throwing(ModelSpyFailure)
}

private struct PlainTextLMInputBuilderSpy: PlainTextLMInputBuilding {
    private let recorder = TokenRecorderBox()

    func makeInput(tokens: [Int]) throws -> LMInput {
        recorder.record(tokens)
        throw InputBuilderFailure.intercepted(tokens)
    }

    var recordedTokens: [[Int]] {
        recorder.tokens
    }
}

private final class TokenRecorderBox: @unchecked Sendable {
    private(set) var tokens: [[Int]] = []

    func record(_ tokens: [Int]) {
        self.tokens.append(tokens)
    }
}

private enum InputBuilderFailure: Error, Equatable {
    case intercepted([Int])
}

private enum ModelSpyFailure: Error, Equatable {
    case chatPreparationIntercepted
    case unexpectedChatPreparation
}

private func temporaryModelDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
