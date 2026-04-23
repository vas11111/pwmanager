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

            Button("Quit PWManager") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    private var lockedContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Vault is locked")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var unlockedContent: some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            let results = filteredEntries
            if results.isEmpty {
                Text(searchText.isEmpty ? "No entries" : "No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(results.prefix(10)) { entry in
                            MenuBarEntryRow(entry: entry, viewModel: viewModel)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            Divider()

            Button {
                viewModel.lock()
            } label: {
                Label("Lock Vault", systemImage: "lock")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var filteredEntries: [PasswordEntry] {
        guard !searchText.isEmpty else {
            return Array(viewModel.entries.prefix(10))
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
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.siteName)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(entry.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.copyToClipboard(entry.password)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copy password")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
