import Testing
@testable import LocalMLXChatCore

struct PromptBuilderTests {
    @Test func promptBuilderPassesPromptThroughUnchanged() {
        let builder = PromptBuilder()

        let prompt = builder.makePrompt(from: "Tell me a joke")

        #expect(prompt == "Tell me a joke")
    }

    @Test func promptBuilderPreservesWhitespaceInsidePrompt() {
        let builder = PromptBuilder()

        let prompt = builder.makePrompt(from: "Line 1\n  Line 2")

        #expect(prompt == "Line 1\n  Line 2")
    }
}
