import Foundation

public enum LocalModelStreamEvent: Sendable, Equatable {
    case chunk(String)
    case failed(LocalModelError)
    case finished
}
