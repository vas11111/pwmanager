import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel

    var body: some View {
        NavigationSplitView {
            List(viewModel.filteredEntries, selection: $viewModel.selectedEntryID) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.siteName)
                        .fontWeight(.medium)
                    Text(entry.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search entries")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingAddEntry = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.lock()
                    } label: {
                        Label("Lock", systemImage: "lock")
                    }
                    .help("Lock vault (Cmd+L)")
                }
            }
        } detail: {
            if let entry = viewModel.selectedEntry {
                EntryDetailView(entry: entry, viewModel: viewModel)
            } else {
                ContentUnavailableView {
                    Label(
                        viewModel.entries.isEmpty ? "No Entries" : "Select an Entry",
                        systemImage: viewModel.entries.isEmpty ? "key" : "sidebar.left"
                    )
                } description: {
                    if viewModel.entries.isEmpty {
                        Text("Add your first entry with the + button.")
                    } else {
                        Text("Choose an entry from the sidebar.")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddEntry) {
            EntryFormView(viewModel: viewModel)
        }
    }
}
