import SwiftUI
import PWManagerCore

struct EntryDetailView: View {
    let entry: PasswordEntry
    let viewModel: VaultViewModel
    var onEdit: (PasswordEntry) -> Void

    @State private var showPassword = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 24)

                // Table rows
                tableRow(label: "Username", value: entry.username)
                passwordTableRow
                if let url = entry.url, !url.isEmpty {
                    tableRow(label: "Website", value: url)
                }

                if let notes = entry.notes, !notes.isEmpty {
                    notesRow(notes)
                }

                metadataRow
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete Entry?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { viewModel.deleteEntry(id: entry.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("'\(entry.siteName)' will be permanently deleted.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ThemeIconBadge(size: 44, iconSize: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.siteName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.3)
                if let url = entry.url, let parsed = safeURL(url) {
                    Link(url, destination: parsed)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                headerButton(icon: "pencil") { onEdit(entry) }
                headerButton(icon: "trash") { showingDeleteConfirm = true }
            }
        }
    }

    // MARK: - Table Rows

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
                    .lineLimit(1)

                Spacer()

                copyButton(value)
            }
            .padding(.vertical, 12)

            Divider().overlay(Theme.border)
        }
    }

    private var passwordTableRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Password")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)

                Group {
                    if showPassword {
                        Text(entry.password)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "\u{2022}", count: 14))
                            .foregroundStyle(Theme.text3)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text1)
                .lineLimit(1)
                .frame(height: 16, alignment: .leading)

                Spacer()

                Button {
                    withAnimation(.spring(duration: 0.2)) { showPassword.toggle() }
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.text3)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(GhostButtonStyle())

                copyButton(entry.password)
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

            Text(entry.createdAt, style: .date)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text3)

            Spacer()

            Text("Modified")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)

            Text(entry.modifiedAt, style: .date)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text3)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .frame(width: 28, height: 28)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(GhostButtonStyle())
    }

    private func copyButton(_ value: String) -> some View {
        Button { viewModel.copyToClipboard(value) } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.text3)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(GhostButtonStyle())
        .help("Copy")
    }

    private func safeURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}
