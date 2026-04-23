import SwiftUI
import PWManagerCore

struct EntryDetailView: View {
    let entry: PasswordEntry
    let viewModel: VaultViewModel
    @State private var showPassword = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                fieldCards
                if let notes = entry.notes, !notes.isEmpty { notesSection(notes) }
                metadata
                Spacer(minLength: 20)
            }
            .padding(36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingEdit) {
            EntryFormView(viewModel: viewModel, existing: entry)
                .preferredColorScheme(.dark)
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
        HStack(spacing: 16) {
            ThemeIconBadge(size: 48, iconSize: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.siteName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.4)
                if let url = entry.url, let parsed = safeURL(url) {
                    Link(url, destination: parsed)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                actionButton(icon: "pencil") { showingEdit = true }
                actionButton(icon: "trash") { showingDeleteConfirm = true }
            }
        }
    }

    // MARK: - Fields

    private var fieldCards: some View {
        VStack(spacing: 1) {
            fieldRow(label: "Username", value: entry.username)
            passwordRow
            if let url = entry.url, !url.isEmpty {
                fieldRow(label: "Website", value: url)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.r, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }

    private func fieldRow(label: String, value: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.text3)
                    .tracking(0.6)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text1)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            copyButton(value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.bgCard)
    }

    private var passwordRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PASSWORD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.text3)
                    .tracking(0.6)
                Group {
                    if showPassword {
                        Text(entry.password)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "\u{2022}", count: 16))
                            .foregroundStyle(Theme.text2)
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text1)
                .lineLimit(1)
                .frame(height: 18, alignment: .leading)
            }
            Spacer(minLength: 8)
            Button {
                withAnimation(.spring(duration: 0.2)) { showPassword.toggle() }
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .frame(width: 28, height: 28)
                    .background(Theme.bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(GhostButtonStyle())
            copyButton(entry.password)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.bgCard)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemeLabel(text: "Notes")
            Text(notes)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text1.opacity(0.8))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.r, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.5)
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
                .foregroundStyle(Theme.text3)
                .tracking(0.5)
            Text(date, style: .date)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
    }

    // MARK: - Helpers

    private func actionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .frame(width: 30, height: 30)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(GhostButtonStyle())
    }

    private func copyButton(_ value: String) -> some View {
        Button {
            viewModel.copyToClipboard(value)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text3)
                .frame(width: 28, height: 28)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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
