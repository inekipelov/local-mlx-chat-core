import Foundation

enum PromptPreparationMode: Sendable, Equatable {
    case chatTemplateAvailable
    case plainText
}

struct PromptPreparationModeReader: Sendable {
    func mode(for modelDirectory: URL) -> PromptPreparationMode {
        if hasChatTemplateOverride(in: modelDirectory) {
            return .chatTemplateAvailable
        }

        if tokenizerConfigContainsChatTemplate(in: modelDirectory) {
            return .chatTemplateAvailable
        }

        return .plainText
    }

    private func hasChatTemplateOverride(in modelDirectory: URL) -> Bool {
        if hasChatTemplateJinja(in: modelDirectory) {
            return true
        }

        let chatTemplateJSONURL = modelDirectory.appending(path: "chat_template.json")
        guard
            let data = try? Data(contentsOf: chatTemplateJSONURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }

        return containsSupportedChatTemplate(in: json)
    }

    private func hasChatTemplateJinja(in modelDirectory: URL) -> Bool {
        let chatTemplateJinjaURL = modelDirectory.appending(path: "chat_template.jinja")
        return (try? String(contentsOf: chatTemplateJinjaURL, encoding: .utf8)) != nil
    }

    private func tokenizerConfigContainsChatTemplate(in modelDirectory: URL) -> Bool {
        let tokenizerConfigURL = modelDirectory.appending(path: "tokenizer_config.json")
        guard
            let data = try? Data(contentsOf: tokenizerConfigURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }

        return containsSupportedChatTemplate(in: json)
    }

    private func containsSupportedChatTemplate(in json: [String: Any]) -> Bool {
        guard let template = json["chat_template"] else {
            return false
        }

        return isSupportedChatTemplateValue(template)
    }

    private func isSupportedChatTemplateValue(_ value: Any) -> Bool {
        if value is String {
            return true
        }

        guard let templates = value as? [Any] else {
            return false
        }

        let namedTemplates = templates.compactMap { item -> (name: String, template: String)? in
            guard
                let item = item as? [String: Any],
                let name = item["name"] as? String,
                let template = item["template"] as? String
            else {
                return nil
            }
            return (name, template)
        }

        return namedTemplates.isEmpty == false
    }
}
