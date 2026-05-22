import SwiftUI
import PWManagerCore

struct EntryDetailView: View {
    @Bindable var viewModel: IOSVaultViewModel
    let entry: PasswordEntry
    @State private var showPassword = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                row("Username", entry.username, copy: entry.username)
                row(
                    "Password",
                    showPassword ? entry.password : String(repeating: "•", count: 12),
                    copy: entry.password,
                    monospaced: true,
                    trailing: AnyView(
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(Theme.text3)
                        }
                    )
                )
                if let url = entry.url, !url.isEmpty {
                    row("URL", url, copy: url)
                }
                if let notes = entry.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text3)
                        Text(notes).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text1)
                    }
                    .listRowBackground(Theme.bgCard)
                }
            } header: {
                Text(entry.siteName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .textCase(nil)
                    .padding(.leading, -16)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) {
            EntryFormView(viewModel: viewModel, existing: entry)
        }
        .alert("Delete entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                viewModel.deleteEntry(id: entry.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func row(
        _ label: String,
        _ value: String,
        copy: String,
        monospaced: Bool = false,
        trailing: AnyView? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text3)
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
                    .foregroundStyle(Theme.text1)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            Spacer()
            if let trailing { trailing }
            Button {
                viewModel.copyToClipboard(copy)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Theme.accent)
            }
        }
        .listRowBackground(Theme.bgCard)
    }
}
