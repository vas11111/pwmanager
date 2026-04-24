import SwiftUI
import PWManagerCore

struct SSHKeyRow: View {
    let entry: PasswordEntry
    let viewModel: VaultViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SSH Key")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)

                if let seed = entry.sshKeyData,
                   let sshKey = SSHKey(seed: seed, comment: entry.siteName, entryID: entry.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sshKey.authorizedKeysLine)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.text2)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }

                    Spacer()

                    Button {
                        viewModel.copyToClipboard(sshKey.authorizedKeysLine)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Copy public key")

                    Button {
                        viewModel.removeSSHKey(for: entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Remove SSH key")
                } else {
                    Button {
                        viewModel.generateSSHKey(for: entry)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                            Text("Generate Ed25519 Key")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(.vertical, 12)

            Divider().overlay(Theme.border)
        }
    }
}
