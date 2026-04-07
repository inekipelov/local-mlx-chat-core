import Foundation

extension LocalModelError {
    static func mapInferenceError(_ error: Error) -> LocalModelError {
        if let llmError = error as? LocalModelError {
            return llmError
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty {
            return .inferenceFailed(description)
        }
        return .inferenceFailed(String(describing: error))
    }
}
