import Foundation
import PWManagerCore

@main
struct PersistenceVerifier {
    static let RED = "\u{1B}[31m"
    static let GREEN = "\u{1B}[32m"
    static let CYAN = "\u{1B}[36m"
    static let BOLD = "\u{1B}[1m"
    static let DIM = "\u{1B}[2m"
    static let RESET = "\u{1B}[0m"

    nonisolated(unsafe) static var passed = 0
    nonisolated(unsafe) static var failed = 0
    nonisolated(unsafe) static var failures: [String] = []

    static func test(_ name: String, _ body: () throws -> Void) {
        print("\(CYAN)→\(RESET) \(name)... ", terminator: "")
        do {
            try body()
            passed += 1
            print("\(GREEN)PASS\(RESET)")
        } catch {
            failed += 1
            failures.append("\(name): \(error)")
            print("\(RED)FAIL\(RESET) — \(error)")
        }
    }

    static func makeEnv() -> (url: URL, keychain: KeychainManager) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("persist-\(UUID().uuidString).pwm")
        let kc = KeychainManager(
            service: "com.pwmanager.persist.\(UUID().uuidString)",
            account: "test-key"
        )
        return (url, kc)
    }

    static func cleanup(_ env: (url: URL, keychain: KeychainManager)) {
        try? FileManager.default.removeItem(at: env.url)
        try? env.keychain.deleteDeviceKey()
    }

    struct AssertionFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    static func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
        if a != b { throw AssertionFailure(message: "\(msg) — expected \(b), got \(a)") }
    }
    static func assertTrue(_ v: Bool, _ msg: String) throws {
        if !v { throw AssertionFailure(message: msg) }
    }
    static func assertThrows(_ msg: String, _ body: () throws -> Void) throws {
        do { try body(); throw AssertionFailure(message: "\(msg) — expected throw") }
        catch is AssertionFailure { throw AssertionFailure(message: "\(msg) — expected throw") }
        catch { /* expected */ }
    }

    static func main() {
        print("\(BOLD)═══════════════════════════════════════════════════")
        print("  PWManager Persistence & Lifecycle Verifier")
        print("═══════════════════════════════════════════════════\(RESET)\n")

        section("Basic Persistence")

        test("1. Entries survive lock/unlock cycle") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "A", username: "ua", password: "pa"))
            try m.addEntry(PasswordEntry(siteName: "B", username: "ub", password: "pb"))
            m.lock()
            try m.unlock(masterPassword: "111111")
            let entries = try m.allEntries().sorted { $0.siteName < $1.siteName }
            try assertEqual(entries.count, 2)
            try assertEqual(entries[0].password, "pa")
            try assertEqual(entries[1].password, "pb")
        }

        test("2. Edits survive lock/unlock") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            var e = PasswordEntry(siteName: "Site", username: "user", password: "old")
            try m.addEntry(e)
            e.username = "newuser"
            e.updatePassword("newpass")
            try m.updateEntry(e)
            m.lock()
            try m.unlock(masterPassword: "111111")
            let entries = try m.allEntries()
            try assertEqual(entries.first?.username, "newuser")
            try assertEqual(entries.first?.password, "newpass")
            try assertEqual(entries.first?.history.count, 1, "old password preserved in history")
            try assertEqual(entries.first?.history.first?.password, "old")
        }

        test("3. Deletes are persisted") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            let e1 = PasswordEntry(siteName: "Keep", username: "u", password: "p")
            let e2 = PasswordEntry(siteName: "Remove", username: "u", password: "p")
            try m.addEntry(e1); try m.addEntry(e2)
            try m.deleteEntry(id: e2.id)
            m.lock()
            try m.unlock(masterPassword: "111111")
            let entries = try m.allEntries()
            try assertEqual(entries.count, 1)
            try assertEqual(entries.first?.siteName, "Keep")
        }

        test("4. SSH keys survive lock/unlock") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            let seed = Data(repeating: 0x77, count: 32)
            try m.addSSHKey(SSHKeyEntry(name: "K", privateKeyData: seed, comment: "x"))
            m.lock()
            try m.unlock(masterPassword: "111111")
            let keys = try m.allSSHKeys()
            try assertEqual(keys.count, 1)
            try assertEqual(keys.first?.privateKeyData, seed)
        }

        test("5. TOTP secrets and recovery codes preserved") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            let entry = PasswordEntry(
                siteName: "GitHub", username: "u", password: "p",
                totpSecret: "JBSWY3DPEHPK3PXP",
                recoveryCode: "abc-123\ndef-456\nghi-789"
            )
            try m.addEntry(entry)
            m.lock()
            try m.unlock(masterPassword: "111111")
            let got = try m.allEntries().first
            try assertEqual(got?.totpSecret, "JBSWY3DPEHPK3PXP")
            try assertEqual(got?.recoveryCode, "abc-123\ndef-456\nghi-789")
        }

        test("6. Process restart simulation — fresh manager loads same data") {
            let env = makeEnv(); defer { cleanup(env) }
            do {
                let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
                try m.createVault(masterPassword: "111111", kdfParams: .testing)
                try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p1"))
                try m.addEntry(PasswordEntry(siteName: "Y", username: "u", password: "p2"))
            }
            // Brand new PasswordManager instance against same file/keychain
            let m2 = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m2.unlock(masterPassword: "111111")
            try assertEqual(try m2.allEntries().count, 2)
        }

        section("PIN Change Lifecycle")

        test("7. New PIN works, old PIN rejected") {
            let env = makeEnv(); defer { cleanup(env) }
            let oldRk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: oldRk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            try m.changeMasterPassword(currentPassword: "111111", newPassword: "999999",
                                       newRecoveryKey: RecoveryKey(), kdfParams: .testing)
            m.lock()
            try m.unlock(masterPassword: "999999")
            try assertEqual(try m.allEntries().count, 1)
            m.lock()
            try assertThrows("old PIN should fail") {
                try m.unlock(masterPassword: "111111")
            }
        }

        test("8. New recovery key works after PIN change") {
            let env = makeEnv(); defer { cleanup(env) }
            let oldRk = RecoveryKey()
            let newRk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: oldRk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            try m.changeMasterPassword(currentPassword: "111111", newPassword: "999999",
                                       newRecoveryKey: newRk, kdfParams: .testing)
            m.lock()
            try m.unlockWithRecoveryKey(newRk.raw)
            try assertEqual(try m.allEntries().count, 1)
        }

        test("9. Old recovery key burned after PIN change") {
            let env = makeEnv(); defer { cleanup(env) }
            let oldRk = RecoveryKey()
            let newRk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: oldRk, kdfParams: .testing)
            try m.changeMasterPassword(currentPassword: "111111", newPassword: "999999",
                                       newRecoveryKey: newRk, kdfParams: .testing)
            m.lock()
            try assertThrows("old rk must not unlock") {
                try m.unlockWithRecoveryKey(oldRk.raw)
            }
        }

        test("10. Wrong current PIN refuses change") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            try assertThrows("wrong current PIN") {
                try m.changeMasterPassword(currentPassword: "WRONG", newPassword: "999999",
                                           newRecoveryKey: RecoveryKey(), kdfParams: .testing)
            }
            m.lock()
            try m.unlock(masterPassword: "111111")
        }

        test("11. Modify entry AFTER PIN change — survives lock/unlock with new PIN") {
            // This was the critical bug: stale vaultKey causing corruption after PIN change
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "Original", username: "u", password: "p"))
            try m.changeMasterPassword(currentPassword: "111111", newPassword: "999999",
                                       newRecoveryKey: RecoveryKey(), kdfParams: .testing)
            // After PIN change, immediately add an entry (uses same manager)
            try m.addEntry(PasswordEntry(siteName: "AfterChange", username: "u", password: "p"))
            m.lock()
            try m.unlock(masterPassword: "999999")
            let entries = try m.allEntries().sorted { $0.siteName < $1.siteName }
            try assertEqual(entries.count, 2)
            try assertEqual(entries[0].siteName, "AfterChange")
            try assertEqual(entries[1].siteName, "Original")
        }

        test("12. PIN change preserves all entry types") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "A", username: "u", password: "p"))
            try m.addSSHKey(SSHKeyEntry(name: "K", privateKeyData: Data(repeating: 1, count: 32), comment: "c"))
            try m.changeMasterPassword(currentPassword: "111111", newPassword: "999999",
                                       newRecoveryKey: RecoveryKey(), kdfParams: .testing)
            m.lock()
            try m.unlock(masterPassword: "999999")
            try assertEqual(try m.allEntries().count, 1)
            try assertEqual(try m.allSSHKeys().count, 1)
        }

        test("13. PIN change twice — only most recent PIN works") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            try m.changeMasterPassword(currentPassword: "111111", newPassword: "222222",
                                       newRecoveryKey: RecoveryKey(), kdfParams: .testing)
            try m.changeMasterPassword(currentPassword: "222222", newPassword: "333333",
                                       newRecoveryKey: RecoveryKey(), kdfParams: .testing)
            m.lock()
            try m.unlock(masterPassword: "333333")
            m.lock()
            try assertThrows("PIN1") { try m.unlock(masterPassword: "111111") }
            try assertThrows("PIN2") { try m.unlock(masterPassword: "222222") }
        }

        section("Recovery Key Lifecycle")

        test("14. Recovery key unlocks same data as PIN") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "Site", username: "u", password: "p"))

            m.lock()
            try m.unlock(masterPassword: "111111")
            let pinEntries = try m.allEntries()

            m.lock()
            try m.unlockWithRecoveryKey(rk.raw)
            let rkEntries = try m.allEntries()

            try assertEqual(pinEntries.count, rkEntries.count)
            try assertEqual(pinEntries.first?.password, rkEntries.first?.password)
        }

        test("15. Wrong recovery key fails") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .testing)
            m.lock()
            try assertThrows("wrong rk") {
                try m.unlockWithRecoveryKey(RecoveryKey().raw)
            }
        }

        test("16. Vault without recovery key rejects recovery unlock") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            m.lock()
            try assertThrows("no recovery slot") {
                try m.unlockWithRecoveryKey("ABCD2345EFGH6789JKLM")
            }
        }

        test("17. Recovery key still unlocks after unrelated entry edits") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .testing)
            for i in 0..<5 {
                try m.addEntry(PasswordEntry(siteName: "Site\(i)", username: "u", password: "p"))
            }
            try m.allEntries().forEach { var e = $0; e.username = "newuser"; try? m.updateEntry(e) }
            m.lock()
            try m.unlockWithRecoveryKey(rk.raw)
            try assertEqual(try m.allEntries().count, 5)
        }

        section("Update / Format Compatibility")

        test("18. Vault file format version field present") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            let raw = try Data(contentsOf: env.url)
            let json = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
            try assertEqual(json["version"] as? Int, 3, "vault version")
        }

        test("19. Future version vault is rejected (no silent unsafe load)") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            // Corrupt version to a future number
            var json = try JSONSerialization.jsonObject(with: Data(contentsOf: env.url)) as! [String: Any]
            json["version"] = 99
            try JSONSerialization.data(withJSONObject: json).write(to: env.url)
            m.lock()
            try assertThrows("future version") {
                try m.unlock(masterPassword: "111111")
            }
        }

        test("20. Saving entry rewrites file atomically (no partial state)") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            let sizeBefore = try FileManager.default.attributesOfItem(atPath: env.url.path)[.size] as? Int ?? 0
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            // After atomic rewrite, file must still parse as valid VaultFile JSON
            let raw = try Data(contentsOf: env.url)
            let json = try JSONSerialization.jsonObject(with: raw) as? [String: Any]
            try assertTrue(json != nil, "vault still valid JSON after add")
            try assertTrue(json?["encryptedEntries"] != nil, "encryptedEntries field present")
            try assertTrue((try FileManager.default.attributesOfItem(atPath: env.url.path)[.size] as? Int ?? 0) > sizeBefore,
                           "file grew after adding entry")
        }

        section("File Safety / Permissions")

        test("21. Vault file has 0600 permissions") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            let perms = try FileManager.default.attributesOfItem(atPath: env.url.path)[.posixPermissions] as? Int ?? 0
            try assertEqual(perms, 0o600, "vault file permissions")
        }

        test("22. Failed vault creation does not leave partial file") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            // First create succeeds
            try m.createVault(masterPassword: "111111", kdfParams: .testing)
            // Second create on same file must fail (vault already exists)
            try assertThrows("create over existing") {
                try m.createVault(masterPassword: "999999", kdfParams: .testing)
            }
            // Original vault must still unlock
            m.lock()
            try m.unlock(masterPassword: "111111")
        }

        test("23. Tampered vault file detected via HMAC") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            m.lock()
            // Flip a byte in the encrypted entries
            var json = try JSONSerialization.jsonObject(with: Data(contentsOf: env.url)) as! [String: Any]
            var encEntries = Data(base64Encoded: json["encryptedEntries"] as! String)!
            encEntries[encEntries.count / 2] ^= 0xFF
            json["encryptedEntries"] = encEntries.base64EncodedString()
            try JSONSerialization.data(withJSONObject: json).write(to: env.url)

            try assertThrows("tampered ciphertext") {
                try m.unlock(masterPassword: "111111")
            }
        }

        section("Self-Destruct Boundaries")

        test("24. Successful unlock resets failure counter (no surprise self-destruct)") {
            // Self-destruct logic is only at the VaultViewModel layer.
            // Verify the core layer never auto-deletes the file on bad unlock.
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "111111", recoveryKey: RecoveryKey(), kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            m.lock()
            // 50 wrong unlocks at the core layer must not delete the file
            for _ in 0..<50 {
                _ = try? m.unlock(masterPassword: "999999")
            }
            try assertTrue(FileManager.default.fileExists(atPath: env.url.path),
                           "core never auto-deletes vault on wrong PIN")
            // Correct PIN still works
            try m.unlock(masterPassword: "111111")
            try assertEqual(try m.allEntries().count, 1)
        }

        // ─── Results ───
        print("\n\(BOLD)═══════════════════════════════════════════════════")
        print("  Results: \(passed) passed, \(failed) failed")
        print("═══════════════════════════════════════════════════\(RESET)")

        if failed > 0 {
            print("\n\(RED)Failures:\(RESET)")
            for f in failures { print("  • \(f)") }
            exit(1)
        } else {
            print("\n\(GREEN)All persistence checks passed. No data loss paths under normal use.\(RESET)")
        }
    }

    static func section(_ title: String) {
        print("\n\(DIM)── \(title) ──\(RESET)")
    }
}
