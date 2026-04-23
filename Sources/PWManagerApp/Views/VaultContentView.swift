import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(minWidth: 380)
                .layoutPriority(1)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $viewModel.showingAddEntry) {
            EntryFormView(viewModel: viewModel)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(viewModel.filteredEntries, selection: $viewModel.selectedEntryID) { entry in
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.siteName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(entry.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 3)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search")
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingAddEntry = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .help("New entry (Cmd+N)")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.lock()
                } label: {
                    Label("Lock", systemImage: "lock.fill")
                }
                .help("Lock vault (Cmd+L)")
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let entry = viewModel.selectedEntry {
            EntryDetailView(entry: entry, viewModel: viewModel)
                .id(entry.id)
        } else {
            ContentUnavailableView {
                Label(
                    viewModel.entries.isEmpty ? "No Entries" : "Select an Entry",
                    systemImage: viewModel.entries.isEmpty ? "key" : "sidebar.left"
                )
            } description: {
                Text(
                    viewModel.entries.isEmpty
                        ? "Add your first entry with the + button."
                        : "Choose an entry from the sidebar."
                )
            } actions: {
                if viewModel.entries.isEmpty {
                    Button("Add Entry") {
                        viewModel.showingAddEntry = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
