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

    private var isValid: Bool { !siteName.isEmpty && !username.isEmpty && !password.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existing == nil ? "New Entry" : "Edit Entry")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().overlay(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    formSection("Details") {
                        ThemeTextField(placeholder: "Site name", text: $siteName)
                        ThemeTextField(placeholder: "Username or email", text: $username)
                        ThemeTextField(placeholder: "URL (optional)", text: $url)
                    }

                    formSection("Password") {
                        HStack(spacing: 8) {
                            ThemeTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: !showPassword
                            )

                            iconButton(showPassword ? "eye.slash" : "eye") {
                                showPassword.toggle()
                            }
                            iconButton("wand.and.stars", active: showGenerator) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showGenerator.toggle()
                                }
                            }
                        }

                        PasswordStrengthBar(password: password)

                        if showGenerator {
                            generatorPanel
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    formSection("Notes") {
                        TextEditor(text: $notes)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text1)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(height: 80)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 0.5)
                            )
                    }
                }
                .padding(24)
            }

            Divider().overlay(Theme.border)

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .foregroundStyle(Theme.text2)

                Spacer()

                Button { save() } label: {
                    Text(existing == nil ? "Add Entry" : "Save")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(isValid ? Theme.accent : Theme.accent.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 560)
        .background(Theme.bg)
    }

    // MARK: - Generator

    private var generatorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Length: \(Int(genLength))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text2)
                    .monospacedDigit()
                    .frame(width: 72, alignment: .leading)
                Slider(value: $genLength, in: 8...64, step: 1)
                    .tint(Theme.accent)
            }

            HStack(spacing: 14) {
                Toggle("a-z", isOn: $genLowercase)
                Toggle("A-Z", isOn: $genUppercase)
                Toggle("0-9", isOn: $genDigits)
                Toggle("#$%", isOn: $genSymbols)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.text2)

            Button {
                password = generatePassword()
                showGenerator = false
                showPassword = true
            } label: {
                Text("Generate & Fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func formSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ThemeLabel(text: title)
            VStack(spacing: 8) { content() }
        }
    }

    private func iconButton(_ icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Theme.accent : Theme.text3)
                .frame(width: 32, height: 32)
                .background(Theme.bgField)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Theme.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        if var entry = existing {
            entry.siteName = siteName
            entry.username = username
            entry.password = password
            entry.url = url.isEmpty ? nil : url
            entry.notes = notes.isEmpty ? nil : notes
            viewModel.updateEntry(entry)
        } else {
            viewModel.addEntry(siteName: siteName, username: username, password: password, url: url, notes: notes)
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
