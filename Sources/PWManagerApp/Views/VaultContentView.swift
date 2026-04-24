import SwiftUI
import PWManagerCore

struct VaultContentView: View {
    @Bindable var viewModel: VaultViewModel
    @State private var hovered: UUID?
    @State private var editingEntry: PasswordEntry?
    @State private var editingSSHKey: SSHKeyEntry?
    @State private var isAddingLogin = false
    @State private var isAddingSSHKey = false
    @State private var addFormSessionID = UUID()
    @State private var showDeleteConfirm = false
    @State private var pendingCloseAction: (() -> Void)?
    @State private var showUnsavedWarning = false

    private var showingForm: Bool {
        isAddingLogin || isAddingSSHKey || editingEntry != nil || editingSSHKey != nil
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.border).frame(width: 0.5)
            detailPane
        }
        .background(Theme.bg)
        .toast($viewModel.toastMessage)
        .focusable()
        .onKeyPress(.downArrow) { viewModel.selectNext(); return .handled }
        .onKeyPress(.upArrow) { viewModel.selectPrevious(); return .handled }
        .onKeyPress(.return) {
            if viewModel.selectedEntry != nil && !showingForm {
                viewModel.copySelectedPassword()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if showingForm {
                pendingCloseAction = { closeForm() }
                showUnsavedWarning = true
                return .handled
            }
            if viewModel.selectedItemID != nil {
                viewModel.selectedItemID = nil; return .handled
            }
            return .ignored
        }
        .onKeyPress(.delete) {
            guard viewModel.selectedItemID != nil, !showingForm else { return .ignored }
            showDeleteConfirm = true
            return .handled
        }
        .onChange(of: viewModel.showingAddEntry) { _, val in
            if val { openAddLogin(); viewModel.showingAddEntry = false }
        }
        .onChange(of: viewModel.showingAddSSHKey) { _, val in
            if val { openAddSSHKey(); viewModel.showingAddSSHKey = false }
        }
        .alert("Delete Item?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let id = viewModel.selectedItemID {
                    if viewModel.selectedSection == .sshKeys {
                        viewModel.deleteSSHKey(id: id)
                    } else {
                        viewModel.deleteEntry(id: id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedWarning) {
            Button("Discard", role: .destructive) {
                pendingCloseAction?()
                pendingCloseAction = nil
            }
            Button("Keep Editing", role: .cancel) { pendingCloseAction = nil }
        } message: {
            Text("You have unsaved changes. Discard them?")
        }
    }

    // MARK: - Form Management

    private func openAddLogin() {
        let action = {
            withAnimation(.spring(duration: 0.25)) {
                closeFormState()
                addFormSessionID = UUID()
                isAddingLogin = true
                viewModel.selectedItemID = nil
                viewModel.selectedSection = .logins
            }
        }
        if showingForm {
            pendingCloseAction = action; showUnsavedWarning = true
        } else { action() }
    }

    private func openAddSSHKey() {
        let action = {
            withAnimation(.spring(duration: 0.25)) {
                closeFormState()
                addFormSessionID = UUID()
                isAddingSSHKey = true
                viewModel.selectedItemID = nil
                viewModel.selectedSection = .sshKeys
            }
        }
        if showingForm {
            pendingCloseAction = action; showUnsavedWarning = true
        } else { action() }
    }

    private func closeForm() {
        withAnimation(.spring(duration: 0.25)) { closeFormState() }
    }

    private func closeFormState() {
        isAddingLogin = false
        isAddingSSHKey = false
        editingEntry = nil
        editingSSHKey = nil
    }

    private func startEditLogin(_ entry: PasswordEntry) {
        let action = {
            withAnimation(.spring(duration: 0.25)) {
                closeFormState()
                editingEntry = entry
            }
        }
        if showingForm {
            pendingCloseAction = action; showUnsavedWarning = true
        } else { action() }
    }

    // MARK: - Sidebar

    @AppStorage("screenCaptureProtection") private var screenCaptureProtection = true

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Vault")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .tracking(-0.3)
                if screenCaptureProtection {
                    Image(systemName: "rectangle.inset.filled.and.person.filled")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.accent.opacity(0.6))
                        .help("Screen capture protection active")
                }
                Spacer()
                sidebarButton(icon: "lock.fill", help: "Lock vault (Cmd+L)") { viewModel.lock() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Search
            ThemeTextField(placeholder: "Search...", text: $viewModel.searchText, showClearButton: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Section tabs
            HStack(spacing: 0) {
                ForEach(VaultViewModel.SidebarSection.allCases, id: \.self) { section in
                    sectionTab(section)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Content based on section
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        switch viewModel.selectedSection {
                        case .logins:
                            loginsList
                        case .sshKeys:
                            sshKeysList
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: viewModel.selectedItemID) { _, newID in
                    if let id = newID {
                        withAnimation(.spring(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }

            // Add button at bottom
            Divider().overlay(Theme.border)
            addButton
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }

    private func sectionTab(_ section: VaultViewModel.SidebarSection) -> some View {
        let isActive = viewModel.selectedSection == section
        let count = section == .logins ? viewModel.filteredEntries.count : viewModel.filteredSSHKeys.count
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                viewModel.selectedSection = section
                viewModel.selectedItemID = nil
                closeFormState()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: section == .logins ? "key.fill" : "terminal")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(section.rawValue)")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isActive ? Theme.accent : Theme.text3)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isActive ? Theme.accent.opacity(0.15) : Theme.bgField)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? Theme.text1 : Theme.text3)
            .background(
                RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                    .fill(isActive ? Theme.bgSelected : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Login List

    private var loginsList: some View {
        ForEach(viewModel.filteredEntries) { entry in
            SidebarRow(
                name: entry.siteName,
                subtitle: entry.username,
                icon: "key.fill",
                isSelected: viewModel.selectedItemID == entry.id && !showingForm,
                isHovered: hovered == entry.id,
                isBreached: viewModel.breachResults[entry.id]?.isBreached == true
            )
            .id(entry.id)
            .onTapGesture {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.selectedItemID = entry.id
                    closeFormState()
                }
            }
            .onHover { hovered = $0 ? entry.id : nil }
            .contextMenu {
                Button("Copy Password") { viewModel.copyToClipboard(entry.password) }
                Button("Copy Username") { viewModel.copyToClipboard(entry.username) }
                if let secret = entry.totpSecret, !secret.isEmpty,
                   let code = TOTPGenerator.generateCode(secret: secret) {
                    Button("Copy 2FA Code") { viewModel.copyToClipboard(code) }
                }
                Divider()
                Button("Edit") { startEditLogin(entry) }
                Divider()
                Button("Delete", role: .destructive) { viewModel.deleteEntry(id: entry.id) }
            }
        }
    }

    // MARK: - SSH Keys List

    private var sshKeysList: some View {
        ForEach(viewModel.filteredSSHKeys) { key in
            SidebarRow(
                name: key.name,
                subtitle: key.comment,
                icon: "terminal",
                isSelected: viewModel.selectedItemID == key.id && !showingForm,
                isHovered: hovered == key.id
            )
            .id(key.id)
            .onTapGesture {
                withAnimation(.spring(duration: 0.2)) {
                    viewModel.selectedItemID = key.id
                    closeFormState()
                }
            }
            .onHover { hovered = $0 ? key.id : nil }
            .contextMenu {
                if let sshKey = SSHKey(seed: key.privateKeyData, comment: key.comment, entryID: key.id) {
                    Button("Copy Public Key") { viewModel.copyToClipboard(sshKey.authorizedKeysLine) }
                }
                Divider()
                Button("Delete", role: .destructive) { viewModel.deleteSSHKey(id: key.id) }
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            if viewModel.selectedSection == .sshKeys {
                openAddSSHKey()
            } else {
                openAddLogin()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(viewModel.selectedSection == .sshKeys ? "New SSH Key" : "New Login")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .help(viewModel.selectedSection == .sshKeys ? "Generate new SSH key" : "Add new login (Cmd+N)")
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if isAddingLogin {
                InlineFormView(viewModel: viewModel, existing: nil, onClose: closeForm)
                    .id("add-login-\(addFormSessionID)")
            } else if let editing = editingEntry {
                InlineFormView(viewModel: viewModel, existing: editing, onClose: closeForm)
                    .id("edit-\(editing.id)")
            } else if isAddingSSHKey {
                SSHKeyFormView(viewModel: viewModel, existing: nil, onClose: closeForm)
                    .id("add-ssh-\(addFormSessionID)")
            } else if let editing = editingSSHKey {
                SSHKeyFormView(viewModel: viewModel, existing: editing, onClose: closeForm)
                    .id("edit-ssh-\(editing.id)")
            } else if viewModel.selectedSection == .logins, let entry = viewModel.selectedEntry {
                EntryDetailView(entry: entry, viewModel: viewModel, onEdit: { startEditLogin($0) })
                    .id(entry.id)
            } else if viewModel.selectedSection == .sshKeys, let key = viewModel.selectedSSHKey {
                SSHKeyDetailView(sshKey: key, viewModel: viewModel, onEdit: { k in
                    withAnimation(.spring(duration: 0.25)) {
                        closeFormState()
                        editingSSHKey = k
                    }
                })
                    .id(key.id)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        let isEmpty = viewModel.selectedSection == .logins
            ? viewModel.entries.isEmpty
            : viewModel.sshKeys.isEmpty

        return VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.bgCard).frame(width: 80, height: 80)
                Image(systemName: isEmpty
                      ? (viewModel.selectedSection == .sshKeys ? "terminal" : "key")
                      : "sidebar.left")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.text3)
            }
            VStack(spacing: 5) {
                Text(isEmpty
                     ? (viewModel.selectedSection == .sshKeys ? "No SSH Keys" : "No Logins Yet")
                     : "Select an Item")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text1)
                Text(isEmpty
                     ? (viewModel.selectedSection == .sshKeys ? "Generate your first SSH key." : "Store your first password.")
                     : "Choose from the sidebar, or use \u{2191}\u{2193} keys.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
            }
            if isEmpty {
                Button {
                    if viewModel.selectedSection == .sshKeys { openAddSSHKey() } else { openAddLogin() }
                } label: {
                    Text(viewModel.selectedSection == .sshKeys ? "New SSH Key" : "Add Login")
                        .frame(width: 120)
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
    }

    private func sidebarButton(icon: String, help: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(GhostButtonStyle())
        .help(help)
    }
}

// MARK: - Sidebar Row (shared by both types)

private struct SidebarRow: View {
    let name: String
    let subtitle: String
    var icon: String = "key.fill"
    let isSelected: Bool
    let isHovered: Bool
    var isBreached: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            ThemeIconBadge(icon: icon, size: 30, iconSize: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Theme.text1.opacity(0.85))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : Theme.text2)
                    .lineLimit(1)
            }
            Spacer()
            if isBreached {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
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
