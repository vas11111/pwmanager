import SwiftUI
import PWManagerCore

struct SSHKeyFormView: View {
    let viewModel: VaultViewModel
    let existing: SSHKeyEntry?
    let onClose: () -> Void

    @State private var name: String
    @State private var comment: String
    @State private var notes: String

    init(viewModel: VaultViewModel, existing: SSHKeyEntry?, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.existing = existing
        self.onClose = onClose
        _name = State(initialValue: existing?.name ?? "")
        _comment = State(initialValue: existing?.comment ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private var isValid: Bool { !name.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(existing == nil ? "New SSH Key" : "Edit SSH Key")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text1)
                        .tracking(-0.3)
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.text3)
                            .frame(width: 26, height: 26)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help("Close")
                }
                .padding(.bottom, 24)

                formRow(label: "Name") {
                    ThemeTextField(placeholder: "e.g. GitHub Deploy Key", text: $name)
                }

                formRow(label: "Comment") {
                    ThemeTextField(placeholder: "e.g. vasil@macbook (optional)", text: $comment)
                }

                formRow(label: "Notes") {
                    TextEditor(text: $notes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text1)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(height: 72)
                        .background(Theme.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                                .stroke(Theme.border, lineWidth: 0.5)
                        )
                }

                if existing == nil {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                        Text("An Ed25519 key pair will be generated automatically.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }
                    .padding(.top, 16)
                }

                // Save button
                HStack {
                    Spacer()
                    Button { save() } label: {
                        Text(existing == nil ? "Generate Key" : "Save Changes")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 160)
                    }
                    .buttonStyle(AccentButtonStyle(disabled: !isValid))
                    .disabled(!isValid)
                }
                .padding(.top, 20)
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formRow(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)
                    .padding(.top, 8)
                content()
            }
            .padding(.vertical, 12)
            Divider().overlay(Theme.border)
        }
    }

    private func save() {
        if let existing {
            var updated = existing
            updated.name = name
            updated.comment = comment.isEmpty ? name : comment
            updated.notes = notes.isEmpty ? nil : notes
            viewModel.updateSSHKeyEntry(updated)
        } else {
            viewModel.addSSHKey(
                name: name,
                comment: comment,
                notes: notes.isEmpty ? nil : notes
            )
        }
        onClose()
    }
}
