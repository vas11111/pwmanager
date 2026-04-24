import SwiftUI
import CryptoKit
import PWManagerCore

struct SSHKeyFormView: View {
    let viewModel: VaultViewModel
    let existing: SSHKeyEntry?
    let onClose: () -> Void

    @State private var name: String
    @State private var comment: String
    @State private var notes: String
    @State private var mode: KeyMode = .generate
    @State private var importText: String = ""
    @State private var importError: String?

    enum KeyMode: String, CaseIterable {
        case generate = "Generate New"
        case importKey = "Import Existing"
    }

    init(viewModel: VaultViewModel, existing: SSHKeyEntry?, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.existing = existing
        self.onClose = onClose
        _name = State(initialValue: existing?.name ?? "")
        _comment = State(initialValue: existing?.comment ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        if existing != nil { return true }
        if mode == .importKey { return parseImportedKey() != nil }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(existing == nil ? "New SSH Key" : "Edit SSH Key")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text1)
                        .tracking(-0.3)
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.text3)
                            .frame(width: 26, height: 26)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Close")
                }
                .padding(.bottom, 24)

                formRow(label: "Name") {
                    ThemeTextField(placeholder: "e.g. GitHub Deploy Key", text: $name)
                }

                formRow(label: "Comment") {
                    ThemeTextField(placeholder: "e.g. vasil@macbook (optional)", text: $comment)
                }

                // Key source (only for new keys)
                if existing == nil {
                    formRow(label: "Key") {
                        VStack(alignment: .leading, spacing: 10) {
                            // Mode picker
                            HStack(spacing: 0) {
                                ForEach(KeyMode.allCases, id: \.self) { m in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            mode = m
                                            importError = nil
                                        }
                                    } label: {
                                        Text(m.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 5)
                                            .foregroundStyle(mode == m ? Theme.text1 : Theme.text3)
                                            .background(
                                                RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                                                    .fill(mode == m ? Theme.bgSelected : .clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if mode == .generate {
                                HStack(spacing: 6) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.accent)
                                    Text("A new Ed25519 key pair will be generated.")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.text2)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Paste your Ed25519 private key (OpenSSH or base64):")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.text2)

                                    TextEditor(text: $importText)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Theme.text1)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .frame(height: 100)
                                        .background(Theme.bgField)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                                                .stroke(importError != nil ? .red.opacity(0.5) : Theme.border, lineWidth: 0.5)
                                        )
                                        .onChange(of: importText) { _, _ in importError = nil }

                                    if let err = importError {
                                        Text(err)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.red)
                                    } else if !importText.isEmpty {
                                        if parseImportedKey() != nil {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                                    .font(.system(size: 10))
                                                Text("Valid Ed25519 key")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(.green)
                                            }
                                        } else {
                                            Text("Invalid key format")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                formRow(label: "Notes") {
                    TextEditor(text: $notes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text1)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(height: 72)
                        .background(Theme.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                                .stroke(Theme.border, lineWidth: 0.5)
                        )
                }

                // Save button
                HStack {
                    Spacer()
                    Button { save() } label: {
                        Text(existing != nil ? "Save Changes" : (mode == .generate ? "Generate Key" : "Import Key"))
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 160)
                    }
                    .buttonStyle(AccentButtonStyle(disabled: !isValid))
                    .disabled(!isValid)
                }
                .padding(.top, 20)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formRow(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)
                    .padding(.top, 8)
                content()
            }
            .padding(.vertical, 12)
            Divider().overlay(Theme.border)
        }
    }

    // MARK: - Actions

    private func save() {
        if let existing {
            var updated = existing
            updated.name = name
            updated.comment = comment.isEmpty ? name : comment
            updated.notes = notes.isEmpty ? nil : notes
            viewModel.updateSSHKeyEntry(updated)
        } else if mode == .importKey {
            guard let keyData = parseImportedKey() else {
                importError = "Could not parse the private key."
                return
            }
            importText = ""
            viewModel.addSSHKey(
                name: name, comment: comment,
                notes: notes.isEmpty ? nil : notes,
                importedKeyData: keyData
            )
        } else {
            viewModel.addSSHKey(
                name: name, comment: comment,
                notes: notes.isEmpty ? nil : notes
            )
        }
        onClose()
    }

    // MARK: - Key Parsing

    private func parseImportedKey() -> Data? {
        let text = importText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Try raw 32-byte base64 (Ed25519 seed)
        if let data = Data(base64Encoded: text), data.count == 32 {
            if (try? Curve25519.Signing.PrivateKey(rawRepresentation: data)) != nil {
                return data
            }
        }

        // Try OpenSSH format: extract the 32-byte Ed25519 seed
        if let data = parseOpenSSHKey(text) {
            return data
        }

        // Try hex-encoded 32-byte seed
        if text.count == 64, let data = hexDecode(text), data.count == 32 {
            if (try? Curve25519.Signing.PrivateKey(rawRepresentation: data)) != nil {
                return data
            }
        }

        return nil
    }

    private func parseOpenSSHKey(_ text: String) -> Data? {
        // OpenSSH private key format:
        // -----BEGIN OPENSSH PRIVATE KEY-----
        // base64 blob
        // -----END OPENSSH PRIVATE KEY-----
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        let b64 = lines.joined()
        guard let blob = Data(base64Encoded: b64), blob.count > 100 else { return nil }

        // Reject passphrase-protected keys: the ciphername field at offset 15
        // must be "none" (length-prefixed string). AUTH_MAGIC is "openssh-key-v1\0" = 15 bytes.
        let noneMarker = Data("none".utf8)
        let cipherOffset = 15 // after "openssh-key-v1\0"
        guard cipherOffset + 4 <= blob.count else { return nil }
        let cipherLen = Int(UInt32(blob[cipherOffset]) << 24 | UInt32(blob[cipherOffset+1]) << 16
                           | UInt32(blob[cipherOffset+2]) << 8 | UInt32(blob[cipherOffset+3]))
        guard cipherLen == 4, cipherOffset + 4 + cipherLen <= blob.count else { return nil }
        let cipherName = blob[(cipherOffset + 4)..<(cipherOffset + 4 + cipherLen)]
        guard cipherName == noneMarker else { return nil }

        let marker = Data("ssh-ed25519".utf8)
        guard let range = blob.range(of: marker) else { return nil }

        // After the marker, there are length-prefixed fields.
        // The private key is 64 bytes (seed + pubkey) after the second occurrence.
        // Find the second occurrence of the marker
        let afterFirst = blob[range.upperBound...]
        guard let range2 = afterFirst.range(of: marker) else { return nil }

        // After second marker: [4-byte len][32-byte pubkey][4-byte len][64-byte privkey(seed+pub)]
        var offset = range2.upperBound
        guard offset + 4 <= blob.count else { return nil }
        let pubLen = Int(UInt32(blob[offset]) << 24 | UInt32(blob[offset+1]) << 16
                        | UInt32(blob[offset+2]) << 8 | UInt32(blob[offset+3]))
        offset += 4 + pubLen
        guard offset + 4 <= blob.count else { return nil }
        let privLen = Int(UInt32(blob[offset]) << 24 | UInt32(blob[offset+1]) << 16
                         | UInt32(blob[offset+2]) << 8 | UInt32(blob[offset+3]))
        offset += 4
        guard privLen == 64, offset + 64 <= blob.count else { return nil }

        // First 32 bytes of the 64-byte field is the seed
        let seed = blob[offset..<offset+32]
        if (try? Curve25519.Signing.PrivateKey(rawRepresentation: seed)) != nil {
            return Data(seed)
        }
        return nil
    }

    private func hexDecode(_ hex: String) -> Data? {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard nextIndex != index else { return nil }
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}
