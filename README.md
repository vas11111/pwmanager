# PWManager

A quantum-safe password manager for macOS, built in Swift. Zero remote dependencies — every line of code is local and audited.

## Security Architecture

```
Master Password ──→ Argon2id (64 MiB, 3 iters) ──→ Master Key ─┐
                                                                 ├─ HKDF ──→ Combined Key ─┐
Device Key (256-bit, macOS Keychain) ────────────────────────────┘                          │
                                                                                            │
ML-KEM-768 Shared Secret (post-quantum) ────────────────── HKDF ───────────────────────────┘
                                                             │
                                                        Vault Key ──→ AES-256-GCM
```

An attacker needs **all three** — your password, your device's Keychain, and the ML-KEM shared secret — to decrypt the vault. The ML-KEM layer ensures the vault is safe even against future quantum computers.

### Cryptographic Stack

| Layer | Algorithm | Purpose |
|---|---|---|
| KDF | **Argon2id** (64 MiB, 3 iters, 4 threads) | Memory-hard password derivation, GPU/ASIC resistant |
| Post-Quantum KEM | **ML-KEM-768** (FIPS 203) | Lattice-based key encapsulation, quantum-safe |
| Symmetric Encryption | **AES-256-GCM** (CryptoKit) | Authenticated encryption with random nonces |
| Key Combination | **HKDF-SHA256** | Domain-separated key derivation |
| Metadata Integrity | **HMAC-SHA256** | Constant-time verified vault header protection |
| Device Binding | **macOS Keychain** | 256-bit key, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| TOTP | **HMAC-SHA1** (RFC 6238) | Time-based one-time passwords |
| SSH Keys | **Ed25519** (CryptoKit) | SSH agent with Curve25519 signing |

## Features

**Core**
- Quantum-safe hybrid encryption (Argon2id + ML-KEM-768 + AES-256-GCM)
- Two-secret model — master password + device key (vault file alone is useless)
- HMAC-verified vault metadata — detects tampering and downgrade attacks
- KDF parameter bounds enforcement — rejects weakened or absurd values
- Change master password with full re-encryption
- Password history — automatically archives previous passwords on change

**Authentication**
- Touch ID unlock via biometric-protected Keychain
- Brute-force lockout (5 attempts → 30s cooldown, persisted across restarts)
- 8-character minimum master password with strength meter

**Password Management**
- Secure password generator (CSPRNG, rejection sampling, configurable charset)
- Built-in TOTP authenticator (RFC 6238, all 5 test vectors verified)
- Password breach detection via Have I Been Pwned (k-anonymity — only 5 chars of SHA-1 hash sent)
- Alphabetical sorting, search, right-click context menus

**SSH Agent**
- Built-in SSH agent at `~/.pwmanager/agent.sock`
- Ed25519 key generation and management per entry
- Implements SSH agent protocol (REQUEST_IDENTITIES + SIGN_REQUEST)
- Private keys never leave the process — SSH clients only receive signatures
- Socket chmod 0600, TOCTOU-safe bind, deleted on vault lock

**macOS Integration**
- Touch ID, auto-lock on sleep/idle, clipboard auto-clear (configurable)
- Screen capture protection (`NSWindow.sharingType = .none`) — enabled by default
- Menu bar extra with quick search and one-click password copy
- Keyboard shortcuts: Cmd+N, Cmd+L, Cmd+Shift+C, Cmd+Shift+U, arrow keys, Enter, Escape
- Window position persistence, About menu, Settings (Cmd+,)

## Build & Run

Requires macOS 14+ and Swift 6.1+ (Command Line Tools — no Xcode needed).

```bash
# Build
swift build --product PWManagerApp

# Run
swift run PWManagerApp

# Run with Touch ID support
swift build --product PWManagerApp && \
codesign -fs - --entitlements entitlements.plist .build/debug/PWManagerApp && \
.build/debug/PWManagerApp

# Run tests
swift test
```

## Setup SSH Agent

```bash
# Add to ~/.zshrc
export SSH_AUTH_SOCK="$HOME/.pwmanager/agent.sock"
```

Then generate an Ed25519 key on any entry in the app, copy the public key to your server's `~/.ssh/authorized_keys`, and `ssh` will use PWManager's keys automatically.

## Supply Chain

**Zero remote dependencies.** Everything is vendored and audited:

| Package | Version | Source | Audit |
|---|---|---|---|
| Argon2 (C) | `f57e61e` | phc-winner-argon2 | No backdoors, matches upstream byte-for-byte |
| SwiftKyber | 3.5.0 | leif-ibsen | FIPS 203 compliant, NTT zetas verified, no kleptographic channels |
| Digest | 1.13.0 | leif-ibsen | Keccak constants match FIPS 202 |
| BigInt | 1.23.0 | leif-ibsen | Pure math, no I/O |
| ASN1 | 2.7.0 | leif-ibsen | Pure parsing, no I/O |

`Package.swift` has no `.package(url:)` declarations. `swift build` fetches nothing from the network.

## Security Testing

71 automated tests including 28 exploit tests covering:

- Vault file contains no plaintext (passwords, usernames, SSH keys, TOTP secrets)
- Wrong password, tampered ciphertext, HMAC tampering all rejected
- KDF downgrade and upper-bound attacks blocked
- Wrong device key, version downgrade, duplicate creation prevented
- Null byte and Unicode normalization password attacks blocked
- Symlink attack on vault file blocked
- SSH agent: garbage input survived, oversized messages rejected, unknown key signing returns FAILURE
- Change password with wrong current password rejected, vault intact
- All operations on locked vault denied

## File Structure

```
Sources/
├── CArgon2/                 Vendored C (phc-winner-argon2)
├── VendoredArgon2/          Swift Argon2 wrapper
├── VendoredKyber/           ML-KEM-768 (FIPS 203)
├── VendoredDigest/          SHA3/SHAKE (FIPS 202)
├── VendoredBigInt/          Arbitrary precision math
├── VendoredASN1/            Key serialization
├── PWManagerCore/           Core library (no UI)
│   ├── Crypto/              CryptoEngine, KeyDerivation, KeychainManager
│   ├── Models/              PasswordEntry, Vault
│   ├── PasswordManager      Main API
│   ├── TOTPGenerator        RFC 6238
│   ├── BreachChecker        HIBP k-anonymity
│   └── SSHAgent             Unix domain socket agent
└── PWManagerApp/            SwiftUI GUI
    ├── ViewModels/          VaultViewModel
    ├── Services/            AutoLock, Biometric
    └── Views/               All screens + reusable Components/
```

## License

MIT
