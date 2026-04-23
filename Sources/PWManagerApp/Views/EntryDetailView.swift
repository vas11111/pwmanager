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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.siteName)
                        .font(.title3.weight(.semibold))
                    if let url = entry.url, let parsed = safeURL(url) {
                        Link(url, destination: parsed)
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.bottom, 20)

                // Fields
                VStack(spacing: 1) {
                    fieldCard(label: "Username", value: entry.username, fieldName: "username")

                    passwordCard

                    if let url = entry.url, !url.isEmpty {
                        fieldCard(label: "URL", value: url, fieldName: "url")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Notes
                if let notes = entry.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.top, 20)
                }

                // Metadata
                HStack(spacing: 20) {
                    metadataLabel("Created", date: entry.createdAt)
                    metadataLabel("Modified", date: entry.modifiedAt)
                    Spacer()
                }
                .padding(.top, 20)
            }
            .padding(28)
        }
        .toolbar {
            ToolbarItem {
                Button { showingEdit = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            ToolbarItem {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EntryFormView(viewModel: viewModel, existing: entry)
        }
        .alert("Delete Entry?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                viewModel.deleteEntry(id: entry.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("'\(entry.siteName)' will be permanently deleted.")
        }
    }

    // MARK: - Field Cards

    private func fieldCard(label: String, value: String, fieldName: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
            Spacer(minLength: 16)
            copyButton(value, fieldName: fieldName)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
    }

    private var passwordCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Group {
                    if showPassword {
                        Text(entry.password)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "\u{2022}", count: 16))
                    }
                }
                .font(.body)
                .lineLimit(1)
                .frame(height: 18, alignment: .leading)
            }
            Spacer(minLength: 16)
            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .frame(width: 20)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            copyButton(entry.password, fieldName: "password")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Helpers

    private func copyButton(_ value: String, fieldName: String) -> some View {
        Button {
            viewModel.copyToClipboard(value)
            withAnimation(.easeInOut(duration: 0.2)) { copiedField = fieldName }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { if copiedField == fieldName { copiedField = nil } }
            }
        } label: {
            Image(systemName: copiedField == fieldName ? "checkmark.circle.fill" : "doc.on.doc")
                .frame(width: 20)
                .foregroundStyle(copiedField == fieldName ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .help(copiedField == fieldName ? "Copied" : "Copy \(fieldName)")
    }

    private func metadataLabel(_ label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.quaternary)
            Text(date, style: .date)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func safeURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }
}
