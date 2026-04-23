import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(minWidth: 400)
                .layoutPriority(1)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $viewModel.showingAddEntry) {
            EntryFormView(viewModel: viewModel)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Entry count header
            HStack {
                ThemeSectionLabel(text: "\(viewModel.filteredEntries.count) items")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            List(viewModel.filteredEntries, selection: $viewModel.selectedEntryID) { entry in
                SidebarRow(entry: entry)
            }
            .listStyle(.sidebar)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.showingAddEntry = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .help("New entry (Cmd+N)")
            }

            ToolbarItem(placement: .automatic) {
                Button { viewModel.lock() } label: {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
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
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 72, height: 72)
                Image(systemName: viewModel.entries.isEmpty ? "key" : "sidebar.left")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: 4) {
                Text(viewModel.entries.isEmpty ? "No Entries Yet" : "Select an Entry")
                    .font(.system(size: 15, weight: .semibold))
                Text(viewModel.entries.isEmpty
                     ? "Add your first password to get started."
                     : "Choose an entry from the sidebar.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            if viewModel.entries.isEmpty {
                Button {
                    viewModel.showingAddEntry = true
                } label: {
                    Text("Add Entry")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let entry: PasswordEntry

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.siteName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(entry.username)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
