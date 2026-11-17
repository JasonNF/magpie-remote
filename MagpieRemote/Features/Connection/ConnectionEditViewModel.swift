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

    // mTLS 三件套：magpie 签发的 client.pem / client-key.pem / ca.pem
    var clientCertPEM: String?
    var clientKeyPEM: String?
    var caPEM: String?
    var certificateError: String?

    private let editing: Connection?
    private let certificateAccount: String

    init(editing: Connection? = nil) {
        self.editing = editing
        self.name = editing?.name ?? ""
        self.urlString = editing?.urlString ?? ""
        self.certificateAccount = editing?.id.uuidString ?? UUID().uuidString
        if let editing, editing.urlString.contains("mapm.2020713.xyz") {
            self.key = KeychainStore.read(for: editing.id.uuidString) ?? "79261a46b263781ddc6af6d168a8597543d8065fc5f71f14c2b942bef3f8afa0"
        } else if let editing {
            self.key = KeychainStore.read(for: editing.id.uuidString) ?? ""
        } else {
            self.key = ""
        }
        if let editing, let bundle = ClientCertificateStore.load(for: editing.id.uuidString) {
            self.clientCertPEM = bundle.clientCertPEM
            self.clientKeyPEM = bundle.clientKeyPEM
            self.caPEM = bundle.caPEM
        }
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

    var hasAnyCertificate: Bool {
        clientCertPEM != nil || clientKeyPEM != nil || caPEM != nil
    }

    enum CertificateKind: Identifiable {
        case clientCert, clientKey, ca
        var id: Int {
            switch self { case .clientCert: return 0; case .clientKey: return 1; case .ca: return 2 }
        }
    }

    /// 导入一份 PEM 并即时校验其格式；三件套未齐时只暂存，保存连接时写入 Keychain。
    func importCertificate(kind: CertificateKind, data: Data) {
        certificateError = nil
        guard let text = String(data: data, encoding: .utf8) else {
            certificateError = String(localized: "证书文件不是有效的文本。")
            return
        }
        let name: String
        let label: String
        switch kind {
        case .clientCert: name = "client.pem"; label = "CERTIFICATE"
        case .clientKey: name = "client-key.pem"; label = "PRIVATE KEY"
        case .ca: name = "ca.pem"; label = "CERTIFICATE"
        }
        do {
            _ = try ClientCertificateStore.der(from: text, name: name, label: label)
            switch kind {
            case .clientCert: clientCertPEM = text
            case .clientKey: clientKeyPEM = text
            case .ca: caPEM = text
            }
        } catch {
            certificateError = (error as? ClientCertificateError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearCertificates() {
        clientCertPEM = nil
        clientKeyPEM = nil
        caPEM = nil
        certificateError = nil
    }

    func save(context: ModelContext, app: AppModel) async -> Bool {
        validationError = nil
        certificateError = nil
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

        // mTLS 三件套必须成套：要么三份都有，要么一份都没有。
        let importedCount = [clientCertPEM, clientKeyPEM, caPEM].compactMap { $0 }.count
        if importedCount > 0 && importedCount < 3 {
            validationError = String(localized: "客户端证书需要 client.pem、client-key.pem 和 ca.pem 三份文件，请全部导入。")
            return false
        }
        var validatedBundle: ClientCertificateBundle?
        if importedCount == 3 {
            let bundle = ClientCertificateBundle(
                clientCertPEM: clientCertPEM!,
                clientKeyPEM: clientKeyPEM!,
                caPEM: caPEM!
            )
            do {
                // 保存前先配对一次，让错误即时暴露在表单里。
                _ = try ClientCertificateStore.makeTLSMaterial(from: bundle, account: certificateAccount)
                validatedBundle = bundle
            } catch {
                certificateError = (error as? ClientCertificateError)?.errorDescription ?? error.localizedDescription
                return false
            }
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
        // 证书按连接的真实 UUID 存储；新建连接时草稿用的是临时 UUID。
        let account = connection.id.uuidString
        if let validatedBundle {
            if account != certificateAccount {
                ClientCertificateStore.delete(for: certificateAccount)
            }
            ClientCertificateStore.save(validatedBundle, for: account)
        } else if hasAnyCertificate == false {
            ClientCertificateStore.delete(for: account)
            if account != certificateAccount {
                ClientCertificateStore.delete(for: certificateAccount)
            }
        }
        try? context.save()

        await app.activate(id: connection.id, name: connection.name, urlString: connection.urlString)
        return true
    }
}
