import SwiftUI
import PWManagerCore

struct EntryFormView: View {
    let viewModel: VaultViewModel
    let existing: PasswordEntry?
    @Environment(\.dismiss) private var dismiss

    @State private var siteName: String
    @State private var username: String
    @State private var password: String
    @State private var url: String
    @State private var notes: String
    @State private var showPassword = false
    @State private var showGenerator = false
    @State private var genLength: Double = 24
    @State private var genLowercase = true
    @State private var genUppercase = true
    @State private var genDigits = true
    @State private var genSymbols = true

    init(viewModel: VaultViewModel, existing: PasswordEntry? = nil) {
        self.viewModel = viewModel
        self.existing = existing
        _siteName = State(initialValue: existing?.siteName ?? "")
        _username = State(initialValue: existing?.username ?? "")
        _password = State(initialValue: existing?.password ?? "")
        _url = State(initialValue: existing?.url ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    private var isValid: Bool {
        !siteName.isEmpty && !username.isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existing == nil ? "New Entry" : "Edit Entry")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider().opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        ThemeSectionLabel(text: "Details")
                        VStack(spacing: 8) {
                            ThemeTextField(placeholder: "Site Name", text: $siteName)
                            ThemeTextField(placeholder: "Username or Email", text: $username)
                            ThemeTextField(placeholder: "URL (optional)", text: $url)
                        }
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 12) {
                        ThemeSectionLabel(text: "Password")
                        HStack(spacing: 8) {
                            ThemeTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: !showPassword
                            )

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.textTertiary)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showGenerator.toggle()
                                }
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(showGenerator ? Theme.accent : Theme.textTertiary)
                        }

                        if showGenerator {
                            generatorControls
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        ThemeSectionLabel(text: "Notes")
                        TextEditor(text: $notes)
                            .font(.system(size: 13, weight: .medium))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(height: 72)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Theme.borderSoft, lineWidth: 0.5)
                            )
                    }
                }
                .padding(24)
            }

            Divider().opacity(0.5)

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Add Entry" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 460, height: 540)
    }

    // MARK: - Generator

    private var generatorControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Length: \(Int(genLength))")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 70, alignment: .leading)
                Slider(value: $genLength, in: 8...64, step: 1)
            }

            HStack(spacing: 14) {
                Toggle("a-z", isOn: $genLowercase)
                Toggle("A-Z", isOn: $genUppercase)
                Toggle("0-9", isOn: $genDigits)
                Toggle("#$%", isOn: $genSymbols)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 11, weight: .medium))

            Button {
                password = generatePassword()
                showGenerator = false
                showPassword = true
            } label: {
                Text("Generate & Fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Actions

    private func save() {
        if var entry = existing {
            entry.siteName = siteName
            entry.username = username
            entry.password = password
            entry.url = url.isEmpty ? nil : url
            entry.notes = notes.isEmpty ? nil : notes
            viewModel.updateEntry(entry)
        } else {
            viewModel.addEntry(
                siteName: siteName,
                username: username,
                password: password,
                url: url,
                notes: notes
            )
        }
        dismiss()
    }

    private func generatePassword() -> String {
        var sets: [PasswordGenerator.CharacterSet] = []
        if genLowercase { sets.append(.lowercase) }
        if genUppercase { sets.append(.uppercase) }
        if genDigits { sets.append(.digits) }
        if genSymbols { sets.append(.symbols) }
        if sets.isEmpty { sets = [.lowercase, .uppercase, .digits] }
        return PasswordGenerator.generate(length: Int(genLength), using: sets)
    }
}
