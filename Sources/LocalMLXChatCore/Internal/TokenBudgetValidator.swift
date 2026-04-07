import Foundation

struct TokenBudgetValidator: Sendable {
    func validate(
        promptTokenCount: Int,
        requestedOutputTokens: Int,
        availableContextWindow: Int?
    ) throws {
        guard let availableContextWindow else {
            return
        }

        if promptTokenCount >= availableContextWindow {
            throw LocalModelError.contextWindowExceeded(
                promptTokens: promptTokenCount,
                requestedOutputTokens: requestedOutputTokens,
                availableContextWindow: availableContextWindow
            )
        }

        if promptTokenCount + requestedOutputTokens > availableContextWindow {
            throw LocalModelError.contextWindowExceeded(
                promptTokens: promptTokenCount,
                requestedOutputTokens: requestedOutputTokens,
                availableContextWindow: availableContextWindow
            )
        }
    }
}
