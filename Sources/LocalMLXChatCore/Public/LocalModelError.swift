import Foundation

public enum LocalModelError: Error, Equatable, Sendable {
    case invalidModelPath(String)
    case modelLoadFailed(String)
    case inferenceFailed(String)
    case contextWindowExceeded(
        promptTokens: Int,
        requestedOutputTokens: Int,
        availableContextWindow: Int
    )
}
