import Foundation

actor ModelStore {
    private var cachedModel: (any LoadedModel)?
    private var inFlightLoad: Task<any LoadedModel, Error>?

    func model(configuration: LocalModelConfiguration, repository: ModelRepository) async throws -> any LoadedModel {
        if let cachedModel {
            return cachedModel
        }
        if let inFlightLoad {
            return try await inFlightLoad.value
        }

        let loadTask = Task {
            try await repository.loadModel(using: configuration)
        }
        inFlightLoad = loadTask

        do {
            let loaded = try await loadTask.value
            cachedModel = loaded
            inFlightLoad = nil
            return loaded
        } catch {
            inFlightLoad = nil
            throw error
        }
    }
}
