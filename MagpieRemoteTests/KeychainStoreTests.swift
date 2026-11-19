import XCTest
@testable import MagpieRemote

final class KeychainStoreTests: XCTestCase {
    func testMigratesLegacyKeyBeforeRemovingPlaintext() {
        let account = UUID().uuidString
        let legacyKey = "magpie_vault_\(account)"
        let defaults = UserDefaults.standard
        defer { KeychainStore.delete(for: account) }

        defaults.set("legacy-fixture-key", forKey: legacyKey)

        XCTAssertEqual(KeychainStore.read(for: account), "legacy-fixture-key")
        XCTAssertNil(defaults.object(forKey: legacyKey))
        XCTAssertEqual(KeychainStore.read(for: account), "legacy-fixture-key")
    }

    func testPrefersKeychainAndDoesNotLeaveAPlaintextCopy() {
        let account = UUID().uuidString
        let legacyKey = "magpie_vault_\(account)"
        let defaults = UserDefaults.standard
        defer { KeychainStore.delete(for: account) }

        XCTAssertTrue(KeychainStore.save("current-fixture-key", for: account))
        XCTAssertNil(defaults.object(forKey: legacyKey))
        defaults.set("stale-fixture-key", forKey: legacyKey)
        XCTAssertEqual(KeychainStore.read(for: account), "current-fixture-key")
        XCTAssertNil(defaults.object(forKey: legacyKey))

        XCTAssertTrue(KeychainStore.save("rotated-fixture-key", for: account))
        XCTAssertEqual(KeychainStore.read(for: account), "rotated-fixture-key")
        XCTAssertNil(defaults.object(forKey: legacyKey))
    }
}
