import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel
    @State private var hovered: UUID?
    @State private var editingEntry: PasswordEntry?
    @State private var isAdding = false

    private var showingForm: Bool { isAdding || editingEntry != nil }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            divider
            detailPane
        }
        .background(Theme.bg)
        .toast($viewModel.toastMessage)
        .onKeyPress(.downArrow) { viewModel.selectNext(); return .handled }
        .onKeyPress(.upArrow) { viewModel.selectPrevious(); return .handled }
        .onKeyPress(.return) {
            if viewModel.selectedEntry != nil {
                viewModel.copySelectedPassword()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showingForm { closeForm(); return .handled }
            return .ignored
        }
        .onChange(of: viewModel.showingAddEntry) { _, val in
            if val { isAdding = true; editingEntry = nil; viewModel.showingAddEntry = false }
        }
    }

    private func closeForm() {
        withAnimation(.spring(duration: 0.25)) {
            isAdding = false
            editingEntry = nil
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vault")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.3)
                Spacer()
                HStack(spacing: 4) {
                    sidebarButton(icon: "plus") {
                        withAnimation(.spring(duration: 0.25)) {
                            isAdding = true
                            editingEntry = nil
                            viewModel.selectedEntryID = nil
                        }
                    }
                    sidebarButton(icon: "lock.fill") { viewModel.lock() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ThemeTextField(placeholder: "Search...", text: $viewModel.searchText)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            HStack {
                ThemeLabel(text: "\(viewModel.filteredEntries.count) items")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredEntries) { entry in
                            SidebarRow(
                                entry: entry,
                                isSelected: viewModel.selectedEntryID == entry.id && !showingForm,
                                isHovered: hovered == entry.id
                            )
                            .id(entry.id)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.2)) {
                                    viewModel.selectedEntryID = entry.id
                                    isAdding = false
                                    editingEntry = nil
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
                        withAnimation(.spring(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(width: 0.5)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if isAdding {
                InlineFormView(viewModel: viewModel, existing: nil, onClose: closeForm)
            } else if let editing = editingEntry {
                InlineFormView(viewModel: viewModel, existing: editing, onClose: closeForm)
            } else if let entry = viewModel.selectedEntry {
                EntryDetailView(entry: entry, viewModel: viewModel, onEdit: { e in
                    withAnimation(.spring(duration: 0.25)) { editingEntry = e }
                })
                .id(entry.id)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.bgCard).frame(width: 80, height: 80)
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
                     : "Choose from the sidebar, or use \u{2191}\u{2193} keys.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
            }
            if viewModel.entries.isEmpty {
                Button {
                    withAnimation(.spring(duration: 0.25)) { isAdding = true }
                } label: {
                    Text("Add Entry").frame(width: 120)
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
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
