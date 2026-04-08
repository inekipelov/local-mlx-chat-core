import Foundation

struct TruthfulnessPromptBuilder: Sendable {
    func compose(userPrompt: String) -> String {
        """
        You are a precise assistant.
        Your top priority is correctness, not sounding helpful.

        Use only:
        1. the user's request,
        2. the provided context,
        3. high-confidence general knowledge.

        Rules:
        - Do not invent facts, APIs, file names, commands, citations, dates, current events, or results.
        - If you are not sure, say so directly.
        - If the answer depends on missing information, ask one short clarifying question instead of guessing.
        - If you make an assumption, label it explicitly as: Assumption:
        - If information may be outdated or unverifiable from context, say that you cannot verify it.
        - Do not pad the answer with generic advice or filler.
        - Give the shortest correct answer first.
        - Match the user's language.

        Preferred response behavior:
        - First: direct answer.
        - Then, only if needed: Unknowns / Assumptions / Next step.

        User request:
        \(userPrompt)
        """
    }
}

struct TruthfulnessPromptingGenerator: Generating {
    private let base: any Generating
    private let promptBuilder = TruthfulnessPromptBuilder()

    init(base: any Generating) {
        self.base = base
    }

    func generate(
        using model: any LoadedModel,
        prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration
    ) async throws -> String {
        try await base.generate(
            using: model,
            prompt: promptBuilder.compose(userPrompt: prompt),
            options: options,
            configuration: configuration
        )
    }

    func stream(
        using model: any LoadedModel,
        prompt: String,
        options: EffectiveGenerationOptions,
        configuration: LocalModelConfiguration
    ) throws -> AsyncThrowingStream<String, Error> {
        try base.stream(
            using: model,
            prompt: promptBuilder.compose(userPrompt: prompt),
            options: options,
            configuration: configuration
        )
    }
}
