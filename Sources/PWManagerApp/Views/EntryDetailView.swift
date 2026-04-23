import SwiftUI
import PWManagerCore

struct EntryDetailView: View {
    let entry: PasswordEntry
    let viewModel: VaultViewModel
    @State private var showPassword = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false
    @State private var copiedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                fieldCards
                if let notes = entry.notes, !notes.isEmpty {
                    notesSection(notes)
                }
                metadata
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem {
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            ToolbarItem {
                Button(role: .destructive) { showingDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EntryFormView(viewModel: viewModel, existing: entry)
        }
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "key.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.siteName)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.3)
                if let url = entry.url, let parsed = safeURL(url) {
                    Link(url, destination: parsed)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Field Cards

    private var fieldCards: some View {
        VStack(spacing: 1) {
            fieldRow(label: "Username", value: entry.username, fieldName: "username")
            passwordRow
            if let url = entry.url, !url.isEmpty {
                fieldRow(label: "URL", value: url, fieldName: "url")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .stroke(Theme.borderSoft, lineWidth: 0.5)
        )
    }

    private func fieldRow(label: String, value: String, fieldName: String) -> some View {
        HStack(spacing: 12) {
            ThemeFieldRow(label: label, value: value)
            Spacer(minLength: 8)
            copyButton(value, fieldName: fieldName)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.bgField)
    }

    private var passwordRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("PASSWORD")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(0.6)
                Group {
                    if showPassword {
                        Text(entry.password)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "\u{2022}", count: 14))
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(height: 16, alignment: .leading)
            }
            Spacer(minLength: 8)
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showPassword.toggle() }
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            copyButton(entry.password, fieldName: "password")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.bgField)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemeSectionLabel(text: "Notes")
            Text(notes)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .stroke(Theme.borderSoft, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Metadata

    private var metadata: some View {
        HStack(spacing: 24) {
            metaItem("Created", date: entry.createdAt)
            metaItem("Modified", date: entry.modifiedAt)
            Spacer()
        }
    }

    private func metaItem(_ label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.5)
            Text(date, style: .date)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Copy

    private func copyButton(_ value: String, fieldName: String) -> some View {
        Button {
            viewModel.copyToClipboard(value)
            withAnimation(.easeInOut(duration: 0.15)) { copiedField = fieldName }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { if copiedField == fieldName { copiedField = nil } }
            }
        } label: {
            Image(systemName: copiedField == fieldName ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(copiedField == fieldName ? .green : Theme.textTertiary)
                .frame(width: 24, height: 24)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(copiedField == fieldName ? "Copied" : "Copy \(fieldName)")
    }

    private func safeURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        return url
    }
}
