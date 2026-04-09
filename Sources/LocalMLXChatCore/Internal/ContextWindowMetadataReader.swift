import Foundation

struct ContextWindowMetadataReader: Sendable {
    func effectiveContextWindow(modelDirectory: URL) -> Int? {
        return maxPositionEmbeddings(from: modelDirectory)
    }

    func maxPositionEmbeddings(from modelDirectory: URL) -> Int? {
        let configURL = modelDirectory.appending(path: "config.json")
        guard
            let data = try? Data(contentsOf: configURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let value = json["max_position_embeddings"] as? Int {
            return value
        }

        if let value = json["max_position_embeddings"] as? NSNumber {
            return value.intValue
        }

        if let value = json["max_position_embeddings"] as? String, let parsed = Int(value) {
            return parsed
        }

        return nil
    }
}
