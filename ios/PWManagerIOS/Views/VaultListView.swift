import SwiftUI
import UniformTypeIdentifiers
import PWManagerCore

struct VaultListView: View {
    @Bindable var viewModel: IOSVaultViewModel
    @State private var showAdd = false
    @State private var showSettings = false
    @State private var editingEntry: PasswordEntry?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .background(Theme.bg)
            .navigationTitle("Vault")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                EntryFormView(viewModel: viewModel, existing: nil)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .overlay(alignment: .bottom) {
                if let msg = viewModel.toastMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 80)
                        .transition(.opacity)
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(1.6))
                                viewModel.toastMessage = nil
                            }
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.filteredEntries) { entry in
                NavigationLink {
                    EntryDetailView(viewModel: viewModel, entry: entry)
                } label: {
                    EntryRow(entry: entry, breach: viewModel.breachResults[entry.id])
                }
                .listRowBackground(Theme.bgCard)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteEntry(id: entry.id)
                    } label: { Label("Delete", systemImage: "trash") }
                    Button {
                        viewModel.copyToClipboard(entry.password)
                    } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .tint(Theme.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $viewModel.searchText, prompt: "Search vault")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            Text("Your vault is empty")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.text1)
            Text("Add your first login, SSH key, or 2FA secret\nto get started.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Button {
                showAdd = true
            } label: {
                Label("Add Your First Entry", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EntryRow: View {
    let entry: PasswordEntry
    let breach: BreachResult?

    private var initial: String {
        entry.siteName.first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(initial)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.siteName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text1)
                        .lineLimit(1)
                    if let breach, breach.isBreached {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    if entry.totpSecret != nil {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent.opacity(0.7))
                    }
                }
                Text(entry.username)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
