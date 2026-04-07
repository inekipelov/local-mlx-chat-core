import Foundation

/// A typed event emitted while streaming a generated response.
public enum LocalModelStreamEvent: Sendable, Equatable {
    /// An incremental text chunk produced by the model.
    case chunk(String)
    /// A typed failure that ended the stream.
    case failed(LocalModelError)
    /// A successful end-of-stream marker.
    case finished
}
