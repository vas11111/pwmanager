import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel
    @State private var hovered: UUID?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            divider
            detailPane
        }
        .background(Theme.bg)
        .toast($viewModel.toastMessage)
        .sheet(isPresented: $viewModel.showingAddEntry) {
            EntryFormView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .onKeyPress(.downArrow) { viewModel.selectNext(); return .handled }
        .onKeyPress(.upArrow) { viewModel.selectPrevious(); return .handled }
        .onKeyPress(.return) {
            if viewModel.selectedEntry != nil {
                viewModel.copySelectedPassword()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Vault")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.3)

                Spacer()

                HStack(spacing: 4) {
                    sidebarButton(icon: "plus") { viewModel.showingAddEntry = true }
                    sidebarButton(icon: "lock.fill") { viewModel.lock() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Search
            ThemeTextField(placeholder: "Search...", text: $viewModel.searchText)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Count
            HStack {
                ThemeLabel(text: "\(viewModel.filteredEntries.count) items")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.filteredEntries) { entry in
                            SidebarRow(
                                entry: entry,
                                isSelected: viewModel.selectedEntryID == entry.id,
                                isHovered: hovered == entry.id
                            )
                            .id(entry.id)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.2)) {
                                    viewModel.selectedEntryID = entry.id
                                }
                            }
                            .onHover { hovered = $0 ? entry.id : nil }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: viewModel.selectedEntryID) { _, newID in
                    if let id = newID {
                        withAnimation(.spring(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 0.5)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let entry = viewModel.selectedEntry {
            EntryDetailView(entry: entry, viewModel: viewModel)
                .id(entry.id)
                .transition(.opacity.animation(.easeOut(duration: 0.15)))
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.bgCard)
                    .frame(width: 80, height: 80)
                Image(systemName: viewModel.entries.isEmpty ? "key" : "sidebar.left")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.text3)
            }

            VStack(spacing: 5) {
                Text(viewModel.entries.isEmpty ? "No Entries Yet" : "Select an Entry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text1)
                Text(viewModel.entries.isEmpty
                     ? "Store your first password securely."
                     : "Choose from the sidebar, or use \u{2191}\u{2193} arrow keys.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
            }

            if viewModel.entries.isEmpty {
                Button { viewModel.showingAddEntry = true } label: {
                    Text("Add Entry")
                        .frame(width: 120)
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidebarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(GhostButtonStyle())
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
                    .foregroundStyle(isSelected ? .white : Theme.text1.opacity(0.85))
                    .lineLimit(1)
                Text(entry.username)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : Theme.text2)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.65) : isHovered ? Theme.bgHover : .clear)
        )
        .contentShape(Rectangle())
        .animation(.spring(duration: 0.2), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
