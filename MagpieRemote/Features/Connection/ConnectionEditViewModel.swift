import Foundation
import SwiftData
import Observation

/// 添加/编辑连接的表单 ViewModel：草稿、校验、保存（SwiftData + Keychain + 激活）。
@Observable
@MainActor
final class ConnectionEditViewModel {
    var name: String
    var urlString: String
    var key: String
    var validationError: String?
    var isSaving = false

    private let editing: Connection?

    init(editing: Connection? = nil) {
        self.editing = editing
        self.name = editing?.name ?? ""
        self.urlString = editing?.urlString ?? ""
        self.key = ""
    }

    var isEditing: Bool { editing != nil }

    /// 解析 URL：自动检测用户是否粘贴了包含 `?k=<key>` 的完整带 Key 链接。
    nonisolated static func extractCleanURLAndKey(from input: String) -> (cleanURL: String, extractedKey: String?) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (trimmed, nil) }

        let withScheme = trimmed.contains("://") ? trimmed : "http://" + trimmed
        guard var components = URLComponents(string: withScheme) else {
            return (withScheme, nil)
        }

        var foundKey: String?
        if let queryItems = components.queryItems {
            if let kItem = queryItems.first(where: { $0.name == "k" })?.value {
                foundKey = kItem
            }
            let remaining = queryItems.filter { $0.name != "k" }
            components.queryItems = remaining.isEmpty ? nil : remaining
        }

        let clean = components.url?.absoluteString ?? withScheme
        return (clean, foundKey)
    }

    func save(context: ModelContext, app: AppModel) async -> Bool {
        validationError = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let (normalizedURL, inlineKey) = Self.extractCleanURLAndKey(from: urlString)

        guard !trimmedName.isEmpty else {
            validationError = String(localized: "请填写名称。")
            return false
        }
        guard let url = URL(string: normalizedURL), url.host != nil else {
            validationError = String(localized: "服务器地址无效。")
            return false
        }

        var effectiveKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveKey.isEmpty, let inlineKey, !inlineKey.isEmpty {
            effectiveKey = inlineKey
            self.key = inlineKey
        }

        if !isEditing && effectiveKey.isEmpty {
            validationError = String(localized: "请填写 Web Key（或直接在地址栏粘贴带 ?k= 的完整链接）。")
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let connection: Connection
        if let editing {
            editing.name = trimmedName
            editing.urlString = normalizedURL
            connection = editing
        } else {
            connection = Connection(name: trimmedName, urlString: normalizedURL)
            context.insert(connection)
        }
        if !effectiveKey.isEmpty {
            KeychainStore.save(effectiveKey, for: connection.id.uuidString)
        }
        try? context.save()

        await app.activate(id: connection.id, name: connection.name, urlString: connection.urlString)
        return true
    }
}
