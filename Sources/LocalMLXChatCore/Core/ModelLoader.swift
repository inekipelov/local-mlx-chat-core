import Foundation

protocol LoadedModel: Sendable {}

protocol ModelEngine: Sendable {
    func loadModel(at path: URL) async throws -> any LoadedModel
}

struct ModelRepository: Sendable {
    private let engine: any ModelEngine

    init(engine: any ModelEngine = MLXModelEngine()) {
        self.engine = engine
    }

    func loadModel(using configuration: LocalModelConfiguration) async throws -> any LoadedModel {
        let path = configuration.modelPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path.path(), isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LocalModelError.invalidModelPath(path.path())
        }

        do {
            return try await engine.loadModel(at: path)
        } catch let error as LocalModelError {
            throw error
        } catch {
            throw LocalModelError.modelLoadFailed(Self.describe(error))
        }
    }

    private static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty {
            return description
        }
        return String(describing: error)
    }
}
