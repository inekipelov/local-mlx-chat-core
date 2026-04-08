import Testing
@testable import LocalMLXChatCore

struct TruthfulnessPromptBuilderTests {
    @Test func composeIncludesTruthfulnessContractAndUserRequestMarker() {
        let prompt = TruthfulnessPromptBuilder().compose(userPrompt: "What is Swift?")

        #expect(prompt.contains("Your top priority is correctness, not sounding helpful."))
        #expect(prompt.contains("Do not invent facts, APIs, file names, commands, citations, dates, current events, or results."))
        #expect(prompt.contains("If you are not sure, say so directly."))
        #expect(prompt.contains("If you make an assumption, label it explicitly as: Assumption:"))
        #expect(prompt.contains("User request:"))
        #expect(prompt.contains("What is Swift?"))
    }

    @Test func composeIsDeterministic() {
        let builder = TruthfulnessPromptBuilder()

        let first = builder.compose(userPrompt: "Same input")
        let second = builder.compose(userPrompt: "Same input")

        #expect(first == second)
    }
}
