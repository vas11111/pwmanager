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

            Divider().opacity(0.3)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
        .onChange(of: viewModel.state) { _, newState in
            if newState != .unlocked { searchText = "" }
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("Vault is locked")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(height: 72)
    }

    private var unlockedContent: some View {
        VStack(spacing: 0) {
            ThemeTextField(placeholder: "Search...", text: $searchText)
                .padding(10)

            let results = filteredEntries
            if results.isEmpty {
                Text(searchText.isEmpty ? "No entries" : "No matches")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(height: 44)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results.prefix(8)) { entry in
                            MenuBarEntryRow(entry: entry, viewModel: viewModel)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Divider().opacity(0.3)

            Button {
                viewModel.lock()
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Lock Vault")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\u{2318}L")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    @State private var isHovered = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.siteName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(entry.username)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isHovered || copied {
                Button {
                    guard viewModel.state == .unlocked else { return }
                    viewModel.copyToClipboard(entry.password)
                    withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isHovered ? Theme.bgHover : .clear)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}
