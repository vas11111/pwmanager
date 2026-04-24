import SwiftUI
import CryptoKit
import PWManagerCore

struct SSHKeyDetailView: View {
    let sshKey: SSHKeyEntry
    let viewModel: VaultViewModel
    @State private var showingDeleteConfirm = false

    private var key: SSHKey? {
        SSHKey(seed: sshKey.privateKeyData, comment: sshKey.comment, entryID: sshKey.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 24)
                tableRow(label: "Name", value: sshKey.name)
                tableRow(label: "Comment", value: sshKey.comment)

                if let k = key {
                    publicKeyRow(k)
                    fingerprintRow(k)
                }

                if let notes = sshKey.notes, !notes.isEmpty {
                    notesRow(notes)
                }

                metadataRow
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete SSH Key?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { viewModel.deleteSSHKey(id: sshKey.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("'\(sshKey.name)' will be permanently deleted. Servers using this key will no longer accept connections.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ThemeIconBadge(icon: "terminal", size: 44, iconSize: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(sshKey.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.3)
                Text("Ed25519 SSH Key")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            headerButton(icon: "trash", help: "Delete SSH key") {
                showingDeleteConfirm = true
            }
        }
    }

    // MARK: - Rows

    private func publicKeyRow(_ k: SSHKey) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text("Public Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)
                Text(k.authorizedKeysLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text1)
                    .textSelection(.enabled)
                    .lineLimit(3)
                Spacer()
                copyButton(k.authorizedKeysLine, help: "Copy public key")
            }
            .padding(.vertical, 12)
            Divider().overlay(Theme.border)
        }
    }

    private func fingerprintRow(_ k: SSHKey) -> some View {
        let pubBytes = k.privateKey.publicKey.rawRepresentation
        let hash = SHA256.hash(data: pubBytes)
        let fingerprint = "SHA256:" + Data(hash).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")

        return VStack(spacing: 0) {
            HStack {
                Text("Fingerprint")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)
                Text(fingerprint)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text1)
                    .textSelection(.enabled)
                Spacer()
                copyButton(fingerprint, help: "Copy fingerprint")
            }
            .padding(.vertical, 12)
            Divider().overlay(Theme.border)
        }
    }

    private func tableRow(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text1)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.vertical, 12)
            Divider().overlay(Theme.border)
        }
    }

    private func notesRow(_ notes: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text("Notes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)
                Text(notes)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text1.opacity(0.8))
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.vertical, 12)
            Divider().overlay(Theme.border)
        }
    }

    private var metadataRow: some View {
        HStack {
            Text("Created")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
                .frame(width: 80, alignment: .leading)
            Text(sshKey.createdAt, style: .relative)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text3)
            + Text(" ago")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text3)
            Spacer()
        }
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func headerButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .frame(width: 28, height: 28)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(GhostButtonStyle())
        .help(help)
    }

    private func copyButton(_ value: String, help: String = "Copy") -> some View {
        Button { viewModel.copyToClipboard(value) } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text3)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(GhostButtonStyle())
        .help(help)
    }
}
