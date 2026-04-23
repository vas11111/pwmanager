import SwiftUI
import PWManagerCore

struct MenuBarView: View {
    let viewModel: VaultViewModel
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.state == .unlocked {
                unlockedContent
            } else {
                lockedContent
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit PWManager", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    private var lockedContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("Vault is locked")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(height: 80)
    }

    private var unlockedContent: some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .padding(10)

            let results = filteredEntries
            if results.isEmpty {
                Text(searchText.isEmpty ? "No entries" : "No matches")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(height: 48)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results.prefix(8)) { entry in
                            MenuBarEntryRow(entry: entry, viewModel: viewModel)
                            if entry.id != results.prefix(8).last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            Button {
                viewModel.lock()
            } label: {
                Label("Lock Vault", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var filteredEntries: [PasswordEntry] {
        guard !searchText.isEmpty else {
            return Array(viewModel.entries.prefix(8))
        }
        let q = searchText.lowercased()
        return viewModel.entries.filter {
            $0.siteName.lowercased().contains(q)
                || $0.username.lowercased().contains(q)
        }
    }
}

private struct MenuBarEntryRow: View {
    let entry: PasswordEntry
    let viewModel: VaultViewModel
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.siteName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(entry.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                viewModel.copyToClipboard(entry.password)
                withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Copy password")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}
