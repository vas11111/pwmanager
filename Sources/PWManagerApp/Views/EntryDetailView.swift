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
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.siteName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        if let url = entry.url, let parsed = safeURL(url) {
                            Link(url, destination: parsed)
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                    Spacer()
                }

                Divider()

                fieldRow(label: "Username", value: entry.username, fieldName: "username")

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if showPassword {
                            Text(entry.password)
                                .fontDesign(.monospaced)
                                .textSelection(.enabled)
                        } else {
                            Text(String(repeating: "\u{2022}", count: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    copyButton(entry.password, fieldName: "password")
                }

                if let notes = entry.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Modified")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.modifiedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
        }
        .toolbar {
            Button {
                showingEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
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

    private func fieldRow(label: String, value: String, fieldName: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .textSelection(.enabled)
            }
            Spacer()
            copyButton(value, fieldName: fieldName)
        }
    }

    private func copyButton(_ value: String, fieldName: String) -> some View {
        Button {
            viewModel.copyToClipboard(value)
            copiedField = fieldName
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copiedField == fieldName { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == fieldName ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .help(copiedField == fieldName ? "Copied! Clears in 30s" : "Copy \(fieldName)")
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
