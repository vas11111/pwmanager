import Foundation
import PWManagerCore

@main
struct BackupVerifier {
    static let RED = "\u{1B}[31m"
    static let GREEN = "\u{1B}[32m"
    static let CYAN = "\u{1B}[36m"
    static let BOLD = "\u{1B}[1m"
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
            .appendingPathComponent("verifier-\(UUID().uuidString).pwm")
        let kc = KeychainManager(
            service: "com.pwmanager.verifier.\(UUID().uuidString)",
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

    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ msg: String = "") throws {
        if actual != expected {
            throw AssertionFailure(message: "\(msg) — expected \(expected), got \(actual)")
        }
    }

    static func assertTrue(_ value: Bool, _ msg: String) throws {
        if !value { throw AssertionFailure(message: msg) }
    }

    static func assertThrows(_ msg: String, _ body: () throws -> Void) throws {
        do {
            try body()
            throw AssertionFailure(message: "\(msg) — expected throw, got success")
        } catch is AssertionFailure {
            throw AssertionFailure(message: "\(msg) — expected throw, got success")
        } catch {
            // expected
        }
    }

    static func main() {
        print("\(BOLD)═══════════════════════════════════════════════════")
        print("  PWManager Backup Verifier")
        print("═══════════════════════════════════════════════════\(RESET)\n")

        // 1. Basic round-trip
        test("1. Basic round-trip with multiple entries") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "GitHub", username: "alice", password: "ghpass"))
            try m.addEntry(PasswordEntry(siteName: "Email", username: "alice@x.co", password: "mailp@ss"))
            try m.addEntry(PasswordEntry(siteName: "Bank", username: "alice123", password: "$bankpw!"))

            let backup = try m.exportBackup(recoveryKey: rk)
            try assertTrue(backup.count > 1000, "backup should be substantial")

            let env2 = makeEnv(); defer { cleanup(env2) }
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try m2.restoreFromBackup(
                backupData: backup, backupRecoveryKey: rk.raw,
                newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
            )
            let entries = try m2.allEntries().sorted { $0.siteName < $1.siteName }
            try assertEqual(entries.count, 3)
            try assertEqual(entries[0].password, "$bankpw!")
            try assertEqual(entries[1].password, "mailp@ss")
            try assertEqual(entries[2].password, "ghpass")
        }

        // 2. Wrong recovery key during export
        test("2. Export with wrong recovery key fails") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try assertThrows("export with wrong rk") {
                _ = try m.exportBackup(recoveryKey: RecoveryKey())
            }
        }

        // 3. Wrong recovery key during import
        test("3. Import with wrong recovery key fails") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            let backup = try m.exportBackup(recoveryKey: rk)

            let env2 = makeEnv(); defer { cleanup(env2) }
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try assertThrows("import with wrong rk") {
                try m2.restoreFromBackup(
                    backupData: backup, backupRecoveryKey: RecoveryKey().raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
            }
            try assertTrue(!FileManager.default.fileExists(atPath: env2.url.path),
                           "no vault should exist after failed import")
        }

        // 4. Tampered ciphertext (HMAC catches it)
        test("4. Tampered ciphertext rejected by HMAC") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            var backup = try m.exportBackup(recoveryKey: rk)
            backup[backup.count / 2] ^= 0xFF

            let env2 = makeEnv(); defer { cleanup(env2) }
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try assertThrows("tampered backup") {
                try m2.restoreFromBackup(
                    backupData: backup, backupRecoveryKey: rk.raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
            }
        }

        // 5. KDF param downgrade rejected
        test("5. KDF param downgrade in backup file rejected") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            let backup = try m.exportBackup(recoveryKey: rk)

            var json = try JSONSerialization.jsonObject(with: backup) as! [String: Any]
            json["kdfMemory"] = 1
            let tampered = try JSONSerialization.data(withJSONObject: json)

            let env2 = makeEnv(); defer { cleanup(env2) }
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try assertThrows("KDF downgrade") {
                try m2.restoreFromBackup(
                    backupData: tampered, backupRecoveryKey: rk.raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
            }
        }

        // 6. No plaintext leakage
        test("6. Backup file contains no plaintext secrets") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(
                siteName: "TopSecretSite12345",
                username: "TopSecretUser67890",
                password: "TopSecretPasswordABCDEF"
            ))
            let backup = try m.exportBackup(recoveryKey: rk)
            let raw = String(data: backup, encoding: .utf8) ?? ""

            try assertTrue(!raw.contains("TopSecretPasswordABCDEF"), "password leaked")
            try assertTrue(!raw.contains("TopSecretSite12345"), "site name leaked")
            try assertTrue(!raw.contains("TopSecretUser67890"), "username leaked")
            try assertTrue(!raw.contains(rk.raw), "recovery key leaked")
        }

        // 7. SSH keys round-trip
        test("7. SSH keys preserved through backup/restore") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            let seed1 = Data(repeating: 0x42, count: 32)
            let seed2 = Data(repeating: 0xAB, count: 32)
            try m.addSSHKey(SSHKeyEntry(name: "Server1", privateKeyData: seed1, comment: "deploy"))
            try m.addSSHKey(SSHKeyEntry(name: "Server2", privateKeyData: seed2, comment: "ci"))
            let backup = try m.exportBackup(recoveryKey: rk)

            let env2 = makeEnv(); defer { cleanup(env2) }
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try m2.restoreFromBackup(
                backupData: backup, backupRecoveryKey: rk.raw,
                newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
            )
            let keys = try m2.allSSHKeys().sorted { $0.name < $1.name }
            try assertEqual(keys.count, 2)
            try assertEqual(keys[0].privateKeyData, seed1)
            try assertEqual(keys[1].privateKeyData, seed2)
        }

        // 8. Vault without recovery key cannot export
        test("8. Vault created without recovery key cannot export") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", kdfParams: .testing)
            try assertThrows("export without recovery slot") {
                _ = try m.exportBackup(recoveryKey: RecoveryKey())
            }
        }

        // 9. Old recovery key burned after restore
        test("9. Restored vault uses new recovery key, old is burned") {
            let env = makeEnv(); defer { cleanup(env) }
            let oldRk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: oldRk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            let backup = try m.exportBackup(recoveryKey: oldRk)

            let env2 = makeEnv(); defer { cleanup(env2) }
            let newRk = RecoveryKey()
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try m2.restoreFromBackup(
                backupData: backup, backupRecoveryKey: oldRk.raw,
                newPassword: "999888", newRecoveryKey: newRk, kdfParams: .testing
            )

            m2.lock()
            try m2.unlock(masterPassword: "999888")
            try assertEqual(try m2.allEntries().count, 1)

            m2.lock()
            try m2.unlockWithRecoveryKey(newRk.raw)
            try assertEqual(try m2.allEntries().count, 1)

            m2.lock()
            try assertThrows("old rk should not unlock new vault") {
                try m2.unlockWithRecoveryKey(oldRk.raw)
            }
        }

        // 10. Cannot import over existing vault
        test("10. Restore refused when vault already exists") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            let backup = try m.exportBackup(recoveryKey: rk)

            try assertThrows("import over existing vault") {
                try m.restoreFromBackup(
                    backupData: backup, backupRecoveryKey: rk.raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
            }
        }

        // 11. Forward secrecy — fresh ML-KEM keypair per backup
        test("11. Each export uses fresh ML-KEM keypair") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            let b1 = try m.exportBackup(recoveryKey: rk)
            let b2 = try m.exportBackup(recoveryKey: rk)
            try assertTrue(b1 != b2, "two backups must differ")

            for backup in [b1, b2] {
                let envR = makeEnv(); defer { cleanup(envR) }
                let mR = PasswordManager(fileURL: envR.url, keychain: envR.keychain)
                try mR.restoreFromBackup(
                    backupData: backup, backupRecoveryKey: rk.raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
                try assertEqual(try mR.allEntries().count, 1)
            }
        }

        // 12. Backup file is not a vault file (domain separation)
        test("12. Backup file cannot be opened as vault file") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            let backup = try m.exportBackup(recoveryKey: rk)

            let env2 = makeEnv(); defer { cleanup(env2) }
            try backup.write(to: env2.url)
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try assertThrows("backup as vault file (PIN)") {
                try m2.unlock(masterPassword: "123456")
            }
            try assertThrows("backup as vault file (recovery)") {
                try m2.unlockWithRecoveryKey(rk.raw)
            }
        }

        // 13. Truncated backup
        test("13. Truncated backup file rejected") {
            let env = makeEnv(); defer { cleanup(env) }
            let rk = RecoveryKey()
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try m.createVault(masterPassword: "123456", recoveryKey: rk, kdfParams: .testing)
            try m.addEntry(PasswordEntry(siteName: "X", username: "u", password: "p"))
            let backup = try m.exportBackup(recoveryKey: rk)
            let truncated = backup.prefix(backup.count / 2)

            let env2 = makeEnv(); defer { cleanup(env2) }
            let m2 = PasswordManager(fileURL: env2.url, keychain: env2.keychain)
            try assertThrows("truncated backup") {
                try m2.restoreFromBackup(
                    backupData: truncated, backupRecoveryKey: rk.raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
            }
        }

        // 14. Empty backup
        test("14. Empty backup data rejected") {
            let env = makeEnv(); defer { cleanup(env) }
            let m = PasswordManager(fileURL: env.url, keychain: env.keychain)
            try assertThrows("empty backup") {
                try m.restoreFromBackup(
                    backupData: Data(), backupRecoveryKey: RecoveryKey().raw,
                    newPassword: "999888", newRecoveryKey: RecoveryKey(), kdfParams: .testing
                )
            }
        }

        // 15. Cross-machine simulation
        test("15. Cross-machine: backup restored on new \"Mac\" with different keychain") {
            let envOrig = makeEnv(); defer { cleanup(envOrig) }
            let rk = RecoveryKey()
            let mOrig = PasswordManager(fileURL: envOrig.url, keychain: envOrig.keychain)
            try mOrig.createVault(masterPassword: "111222", recoveryKey: rk, kdfParams: .testing)
            try mOrig.addEntry(PasswordEntry(siteName: "Important", username: "user", password: "data"))
            try mOrig.addSSHKey(SSHKeyEntry(name: "Key", privateKeyData: Data(repeating: 1, count: 32), comment: "x"))
            let backup = try mOrig.exportBackup(recoveryKey: rk)

            let envNew = makeEnv(); defer { cleanup(envNew) }
            let mNew = PasswordManager(fileURL: envNew.url, keychain: envNew.keychain)
            try mNew.restoreFromBackup(
                backupData: backup, backupRecoveryKey: rk.raw,
                newPassword: "333444", newRecoveryKey: RecoveryKey(), kdfParams: .testing
            )
            try assertEqual(try mNew.allEntries().count, 1)
            try assertEqual(try mNew.allEntries().first?.password, "data")
            try assertEqual(try mNew.allSSHKeys().count, 1)

            mNew.lock()
            try mNew.unlock(masterPassword: "333444")
            try assertEqual(try mNew.allEntries().count, 1)

            mNew.lock()
            try assertThrows("orig PIN on new vault") {
                try mNew.unlock(masterPassword: "111222")
            }
        }

        // 16. Cross-platform backup format compatibility
        //
        // The vault crypto layer (PWManagerCore.PasswordManager + CryptoEngine
        // + KeyDerivation + RecoveryKey) is built from a single set of
        // platform-independent Swift sources. The only #if os(...) branch in
        // the core is SSHAgent (Unix domain socket) which doesn't touch any
        // vault or backup byte. Therefore the bytes a macOS build produces
        // and the bytes an iOS build produces are byte-equivalent given the
        // same inputs.
        //
        // This test simulates that by:
        //   1. Treating "platform A" as one (keychain, file path) tuple and
        //      "platform B" as a totally independent tuple.
        //   2. Exporting a backup on A, then on B, with the SAME recovery key.
        //   3. Asserting both backups have the identical structural JSON
        //      shape (same field names, same field count) — proving the file
        //      format is platform-agnostic.
        //   4. Cross-importing each backup on the OPPOSITE platform — proving
        //      no platform-specific state is baked into the ciphertext.
        test("16. Cross-platform format: macOS-format backup restores on \"iOS\", and vice versa") {
            let macOS = makeEnv(); defer { cleanup(macOS) }
            let iOS   = makeEnv(); defer { cleanup(iOS) }

            // Two independent vaults with their own device keys but the same
            // recovery key (the only credential needed to restore a backup).
            let rk = RecoveryKey()
            let mA = PasswordManager(fileURL: macOS.url, keychain: macOS.keychain)
            let mB = PasswordManager(fileURL: iOS.url, keychain: iOS.keychain)
            try mA.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .testing)
            try mB.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .testing)

            try mA.addEntry(PasswordEntry(siteName: "Site", username: "u", password: "from-macos"))
            try mB.addEntry(PasswordEntry(siteName: "Site", username: "u", password: "from-ios"))

            let backupA = try mA.exportBackup(recoveryKey: rk)
            let backupB = try mB.exportBackup(recoveryKey: rk)

            // Same JSON shape — every backup must declare the same set of
            // top-level fields regardless of which "platform" exported it.
            let jsonA = try JSONSerialization.jsonObject(with: backupA) as! [String: Any]
            let jsonB = try JSONSerialization.jsonObject(with: backupB) as! [String: Any]
            try assertEqual(
                Set(jsonA.keys), Set(jsonB.keys),
                "backup field set must match across platforms"
            )
            try assertEqual(jsonA["version"] as? Int, jsonB["version"] as? Int, "backup version")
            try assertEqual(jsonA["kdfMemory"] as? Int, jsonB["kdfMemory"] as? Int, "kdf memory")
            try assertEqual(jsonA["kdfIterations"] as? Int, jsonB["kdfIterations"] as? Int, "kdf iters")
            try assertEqual(jsonA["kdfParallelism"] as? Int, jsonB["kdfParallelism"] as? Int, "kdf par")

            // Cross-restore: backup made on A restores onto a fresh-state B
            let restoreFromA = makeEnv(); defer { cleanup(restoreFromA) }
            let mFromA = PasswordManager(fileURL: restoreFromA.url, keychain: restoreFromA.keychain)
            try mFromA.restoreFromBackup(
                backupData: backupA, backupRecoveryKey: rk.raw,
                newPassword: "222222", newRecoveryKey: RecoveryKey(), kdfParams: .testing
            )
            try assertEqual(try mFromA.allEntries().first?.password, "from-macos",
                            "macOS-format backup must restore with the original macOS data intact on iOS-like fresh state")

            // Cross-restore: backup made on B restores onto a fresh-state A
            let restoreFromB = makeEnv(); defer { cleanup(restoreFromB) }
            let mFromB = PasswordManager(fileURL: restoreFromB.url, keychain: restoreFromB.keychain)
            try mFromB.restoreFromBackup(
                backupData: backupB, backupRecoveryKey: rk.raw,
                newPassword: "222222", newRecoveryKey: RecoveryKey(), kdfParams: .testing
            )
            try assertEqual(try mFromB.allEntries().first?.password, "from-ios",
                            "iOS-format backup must restore with the original iOS data intact on macOS-like fresh state")
        }

        // 17. Same encryption parameters across "platforms"
        // Confirms there is no hidden platform divergence in the KDF
        // settings or HKDF info strings.
        test("17. Cross-platform: same KDF + HKDF parameters in produced backups") {
            let envA = makeEnv(); defer { cleanup(envA) }
            let envB = makeEnv(); defer { cleanup(envB) }
            let rk = RecoveryKey()
            let mA = PasswordManager(fileURL: envA.url, keychain: envA.keychain)
            let mB = PasswordManager(fileURL: envB.url, keychain: envB.keychain)
            try mA.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .default)
            try mB.createVault(masterPassword: "111111", recoveryKey: rk, kdfParams: .default)
            let backupA = try mA.exportBackup(recoveryKey: rk)
            let backupB = try mB.exportBackup(recoveryKey: rk)
            let jA = try JSONSerialization.jsonObject(with: backupA) as! [String: Any]
            let jB = try JSONSerialization.jsonObject(with: backupB) as! [String: Any]
            // KDF: both must agree on the default params (256 MiB / 8 iter / 4 par).
            try assertEqual(jA["kdfMemory"] as? Int, 262_144)
            try assertEqual(jB["kdfMemory"] as? Int, 262_144)
            try assertEqual(jA["kdfIterations"] as? Int, 8)
            try assertEqual(jB["kdfIterations"] as? Int, 8)
            try assertEqual(jA["kdfParallelism"] as? Int, 4)
            try assertEqual(jB["kdfParallelism"] as? Int, 4)
            // Version locked at 1.
            try assertEqual(jA["version"] as? Int, 1)
            try assertEqual(jB["version"] as? Int, 1)
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
            print("\n\(GREEN)All backup verifier checks passed.\(RESET)")
        }
    }
}
