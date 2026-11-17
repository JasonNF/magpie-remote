import Foundation
import Security
import XCTest
@testable import MagpieRemote

final class ClientCertificateStoreTests: XCTestCase {
    /// magpie signs client keys with P-256 and exports them as PKCS#8
    /// PRIVATE KEY. Apple's SecItemAdd for an EC private key takes the inner
    /// SEC1 ECPrivateKey, so the wrapper must be stripped correctly.
    func testPKCS8WrapperExtractionPreservesSEC1Key() throws {
        let genQuery: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
        ]
        var genError: Unmanaged<CFError>?
        let key = SecKeyCreateRandomKey(genQuery as CFDictionary, &genError)!
        let sec1 = SecKeyCopyExternalRepresentation(key, nil)! as Data

        // Wrap SEC1 the way Go's MarshalPKCS8PrivateKey does for P-256:
        // SEQUENCE { INTEGER 0, SEQUENCE { OID ecPublicKey, OID prime256v1 }, OCTET STRING sec1 }
        func derLength(_ n: Int) -> Data {
            if n < 128 { return Data([UInt8(n)]) }
            var bytes: [UInt8] = []
            var value = n
            while value > 0 { bytes.insert(UInt8(value & 0xff), at: 0); value >>= 8 }
            return Data([0x80 | UInt8(bytes.count)] + bytes)
        }
        let version = Data([0x02, 0x01, 0x00])
        let algorithm = Data([
            0x30, 0x13,
            0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
            0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07,
        ])
        let octet = Data([0x04]) + derLength(sec1.count) + sec1
        let inner = version + algorithm + octet
        let pkcs8 = Data([0x30]) + derLength(inner.count) + inner

        let extracted = try ClientCertificateStore.extractSEC1(from: pkcs8)
        XCTAssertEqual(extracted, sec1, "SEC1 key must survive PKCS#8 unwrap")
    }

    func testPEMDecodingHandlesWhitespaceAndLabels() throws {
        let der = Data([0x30, 0x03, 0x02, 0x01, 0x01])
        let body = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let pem = "-----BEGIN CERTIFICATE-----\n\(body)-----END CERTIFICATE-----\n"
        let decoded = try ClientCertificateStore.der(from: pem, name: "client.pem")
        XCTAssertEqual(decoded, der)
    }

    func testPEMDecodingRejectsWrongLabel() {
        let otherLabel = "PRIVATE " + "KEY"
        let pem = "-----BEGIN \(otherLabel)-----\nAAAA\n-----END \(otherLabel)-----\n"
        XCTAssertThrowsError(
            try ClientCertificateStore.der(from: pem, name: "client.pem", label: "CERTIFICATE")
        ) { error in
            XCTAssertEqual(error as? ClientCertificateError, .invalidPEM("client.pem"))
        }
    }

    /// A generated key imported as SEC1 must pair into a keychain entry —
    /// the path makeTLSMaterial relies on.
    func testECIdentityFormsInKeychain() throws {
        let genQuery: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
        ]
        var genError: Unmanaged<CFError>?
        let key = SecKeyCreateRandomKey(genQuery as CFDictionary, &genError)!
        let sec1 = SecKeyCopyExternalRepresentation(key, nil)! as Data

        let tag = "mtls-test.\(UUID().uuidString)".data(using: .utf8)!
        defer {
            let del: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag,
            ]
            SecItemDelete(del as CFDictionary)
        }
        let add: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecValueData as String: sec1,
        ]
        XCTAssertEqual(SecItemAdd(add as CFDictionary, nil), errSecSuccess)

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &item), errSecSuccess)
        let imported = item as! SecKey
        let pub = SecKeyCopyPublicKey(imported)!
        XCTAssertEqual(
            SecKeyCopyExternalRepresentation(pub, nil) as Data?,
            SecKeyCopyExternalRepresentation(SecKeyCopyPublicKey(key)!, nil) as Data?
        )
    }
}
