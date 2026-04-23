import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel
    @State private var hovered: UUID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detailPane
        }
        .background(Theme.bg)
        .sheet(isPresented: $viewModel.showingAddEntry) {
            EntryFormView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Toolbar area
            HStack {
                Text("Vault")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.2)

                Spacer()

                HStack(spacing: 4) {
                    toolbarButton(icon: "plus", help: "New entry") {
                        viewModel.showingAddEntry = true
                    }
                    toolbarButton(icon: "lock.fill", help: "Lock vault") {
                        viewModel.lock()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search
            ThemeTextField(placeholder: "Search...", text: $viewModel.searchText)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            // Item count
            HStack {
                ThemeLabel(text: "\(viewModel.filteredEntries.count) items")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            // Entry list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.filteredEntries) { entry in
                        SidebarRow(
                            entry: entry,
                            isSelected: viewModel.selectedEntryID == entry.id,
                            isHovered: hovered == entry.id
                        )
                        .onTapGesture { viewModel.selectedEntryID = entry.id }
                        .onHover { hovered = $0 ? entry.id : nil }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 260)
        .background(Theme.bgSidebar)
    }

    // MARK: - Detail

    private var detailPane: some View {
        ZStack {
            Rectangle()
                .fill(Theme.border)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let entry = viewModel.selectedEntry {
                EntryDetailView(entry: entry, viewModel: viewModel)
                    .id(entry.id)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.bgCard)
                    .frame(width: 80, height: 80)
                Image(systemName: viewModel.entries.isEmpty ? "key" : "sidebar.left")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.text3)
            }

            VStack(spacing: 4) {
                Text(viewModel.entries.isEmpty ? "No Entries Yet" : "Select an Entry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text1)
                Text(viewModel.entries.isEmpty
                     ? "Store your first password securely."
                     : "Choose an entry from the sidebar.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
            }

            if viewModel.entries.isEmpty {
                Button {
                    viewModel.showingAddEntry = true
                } label: {
                    Text("Add Entry")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolbarButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .frame(width: 26, height: 26)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let entry: PasswordEntry
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            ThemeIconBadge(size: 30, iconSize: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.siteName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.text1 : Theme.text1.opacity(0.85))
                    .lineLimit(1)
                Text(entry.username)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                .fill(isSelected ? Theme.bgSelected : isHovered ? Theme.bgHover : .clear)
        )
        .contentShape(Rectangle())
    }
}
