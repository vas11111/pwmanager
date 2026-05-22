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
            List {
                if viewModel.filteredEntries.isEmpty {
                    Text("No entries yet. Tap + to add one.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.filteredEntries) { entry in
                        NavigationLink {
                            EntryDetailView(viewModel: viewModel, entry: entry)
                        } label: {
                            EntryRow(entry: entry)
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .searchable(text: $viewModel.searchText, prompt: "Search vault")
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
}

struct EntryRow: View {
    let entry: PasswordEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.siteName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text1)
            Text(entry.username)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
