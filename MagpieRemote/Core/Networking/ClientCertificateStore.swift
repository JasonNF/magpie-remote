import Foundation
import Security

/// magpie 的 mTLS 三件套：`client.pem`、`client-key.pem`（PKCS#8）、`ca.pem`。
///  PEM 原文存在 Keychain（与 Web Key 同域，按连接 UUID 区分），不落 SwiftData。
struct ClientCertificateBundle: Codable, Sendable {
    var clientCertPEM: String
    var clientKeyPEM: String
    var caPEM: String
}

enum ClientCertificateError: LocalizedError, Equatable {
    case invalidPEM(String)
    case keyImport(OSStatus)
    case identityMissing
    case caInvalid

    var errorDescription: String? {
        switch self {
        case .invalidPEM(let name):
            return String(localized: "\(name) 不是有效的 PEM 证书文件。")
        case .keyImport(let status):
            return String(localized: "客户端私钥导入失败（\(status)）。")
        case .identityMissing:
            return String(localized: "无法将客户端证书与私钥配对，请确认三者来自同一次签发。")
        case .caInvalid:
            return String(localized: "CA 证书无效。")
        }
    }
}

/// 客户端证书的持久化与 SecIdentity / CA 构造。
enum ClientCertificateStore {
    private static let service = "app.magpie.remote.clientcert"

    // MARK: - 持久化

    static func save(_ bundle: ClientCertificateBundle, for account: String) {
        guard let data = try? JSONEncoder().encode(bundle) else { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(for account: String) -> ClientCertificateBundle? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let bundle = try? JSONDecoder().decode(ClientCertificateBundle.self, from: data)
        else { return nil }
        return bundle
    }

    static func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        // 同时移除由该证书导入的私钥与证书，避免钥匙串残留。
        let tag = keyTag(for: account)
        let key: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
        ]
        SecItemDelete(key as CFDictionary)
        let cert: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certLabel(for: account),
        ]
        SecItemDelete(cert as CFDictionary)
    }

    static func hasCertificate(for account: String) -> Bool { load(for: account) != nil }

    // MARK: - 构造 TLS 材料

    /// 从三件套构造出 URLSession 认证质询所需的 identity 与服务器 CA 锚点。
    static func makeTLSMaterial(from bundle: ClientCertificateBundle, account: String) throws -> ClientTLSMaterial {
        let certDER = try der(from: bundle.clientCertPEM, name: "client.pem")
        let keyDER = try der(from: bundle.clientKeyPEM, name: "client-key.pem", label: "PRIVATE KEY")
        let caDER = try der(from: bundle.caPEM, name: "ca.pem")

        guard let certificate = SecCertificateCreateWithData(nil, certDER as CFData) else {
            throw ClientCertificateError.invalidPEM("client.pem")
        }
        guard let caCert = SecCertificateCreateWithData(nil, caDER as CFData) else {
            throw ClientCertificateError.caInvalid
        }

        let sec1 = try extractSEC1(from: keyDER)
        let tag = keyTag(for: account)

        // 先清掉同一连接旧的私钥/证书，保证重新导入后配对到最新证书。
        let oldKey: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
        ]
        SecItemDelete(oldKey as CFDictionary)
        let oldCert: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certLabel(for: account),
        ]
        SecItemDelete(oldCert as CFDictionary)

        let addKey: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecValueData as String: sec1,
        ]
        let keyStatus = SecItemAdd(addKey as CFDictionary, nil)
        guard keyStatus == errSecSuccess else { throw ClientCertificateError.keyImport(keyStatus) }

        let addCert: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: certLabel(for: account),
        ]
        let certStatus = SecItemAdd(addCert as CFDictionary, nil)
        guard certStatus == errSecSuccess || certStatus == errSecDuplicateItem else {
            throw ClientCertificateError.invalidPEM("client.pem")
        }

        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var idItem: CFTypeRef?
        guard SecItemCopyMatching(identityQuery as CFDictionary, &idItem) == errSecSuccess else {
            throw ClientCertificateError.identityMissing
        }
        let identity = idItem as! SecIdentity

        // 确认钥匙串配出的 identity 确实是本次导入的证书，避免命中旧的同名条目。
        var pairedCert: SecCertificate?
        SecIdentityCopyCertificate(identity, &pairedCert)
        guard let pairedCert, (SecCertificateCopyData(pairedCert) as Data) == certDER else {
            throw ClientCertificateError.identityMissing
        }

        return ClientTLSMaterial(identity: identity, clientCertificate: certificate, caCertificates: [caCert])
    }

    // MARK: - 工具

    /// 解析 PEM 正文并做 base64 解码。`label` 为 PEM 块类型，默认证书。
    static func der(from pem: String, name: String, label: String = "CERTIFICATE") throws -> Data {
        let begin = "-----BEGIN \(label)-----"
        let end = "-----END \(label)-----"
        guard let startRange = pem.range(of: begin),
              let endRange = pem.range(of: end, range: startRange.upperBound..<pem.endIndex)
        else { throw ClientCertificateError.invalidPEM(name) }
        let body = pem[startRange.upperBound..<endRange.lowerBound]
            .filter { !$0.isWhitespace }
        guard let data = Data(base64Encoded: String(body)) else {
            throw ClientCertificateError.invalidPEM(name)
        }
        return data
    }

    /// 从 PKCS#8 中取出 SEC1 `ECPrivateKey`。Apple 的 SecItemAdd 导入 EC 私钥
    /// 需要 SEC1，而 magpie 导出的是 PKCS#8 包装。
    static func extractSEC1(from pkcs8: Data) throws -> Data {
        let b = [UInt8](pkcs8)

        func tlv(_ offset: Int) throws -> (tag: UInt8, header: Int, length: Int) {
            guard offset + 2 <= b.count else { throw ClientCertificateError.keyImport(errSecParam) }
            let tag = b[offset]
            let first = Int(b[offset + 1])
            if first & 0x80 == 0 { return (tag, 2, first) }
            let count = first & 0x7f
            guard count > 0, count <= 4, offset + 2 + count <= b.count else {
                throw ClientCertificateError.keyImport(errSecParam)
            }
            var length = 0
            for i in 0..<count { length = (length << 8) | Int(b[offset + 2 + i]) }
            return (tag, 2 + count, length)
        }

        let outer = try tlv(0)
        guard outer.tag == 0x30 else { throw ClientCertificateError.keyImport(errSecParam) }
        var offset = outer.header
        let version = try tlv(offset); offset += version.header + version.length
        let algorithm = try tlv(offset); offset += algorithm.header + algorithm.length
        let octet = try tlv(offset)
        guard octet.tag == 0x04,
              offset + octet.header + octet.length <= b.count
        else { throw ClientCertificateError.keyImport(errSecParam) }
        return Data(b[offset + octet.header ..< offset + octet.header + octet.length])
    }

    private static func keyTag(for account: String) -> Data {
        Data("app.magpie.remote.clientcert.\(account)".utf8)
    }

    private static func certLabel(for account: String) -> String {
        "app.magpie.remote.clientcert.\(account)"
    }
}

/// 一次 TLS 握手所需的客户端身份与信任锚点。
struct ClientTLSMaterial: @unchecked Sendable {
    let identity: SecIdentity
    let clientCertificate: SecCertificate
    let caCertificates: [SecCertificate]
}
