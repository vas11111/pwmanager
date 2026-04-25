import SwiftUI
import PWManagerCore

struct InlineFormView: View {
    let viewModel: VaultViewModel
    let existing: PasswordEntry?
    let onClose: () -> Void

    @State private var siteName: String
    @State private var username: String
    @State private var password: String
    @State private var url: String
    @State private var notes: String
    @State private var totpSecret: String
    @State private var recoveryCode: String
    @State private var showRecoveryCode = false
    @State private var showPassword = false
    @State private var showGenerator = false
    @State private var genLength: Double = 24
    @State private var genLowercase = true
    @State private var genUppercase = true
    @State private var genDigits = true
    @State private var genSymbols = true

    init(viewModel: VaultViewModel, existing: PasswordEntry?, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.existing = existing
        self.onClose = onClose
        _siteName = State(initialValue: existing?.siteName ?? "")
        _username = State(initialValue: existing?.username ?? "")
        _password = State(initialValue: existing?.password ?? "")
        _url = State(initialValue: existing?.url ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _totpSecret = State(initialValue: existing?.totpSecret ?? "")
        _recoveryCode = State(initialValue: existing?.recoveryCode ?? "")
    }

    private var isValid: Bool {
        !siteName.isEmpty && !username.isEmpty && !password.isEmpty
            && (totpSecret.isEmpty || TOTPGenerator.isValidSecret(totpSecret))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(existing == nil ? "New Entry" : "Edit Entry")
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
                }
                .padding(.bottom, 24)

                // Fields
                formRow(label: "Site Name") {
                    ThemeTextField(placeholder: "e.g. GitHub", text: $siteName)
                }

                formRow(label: "Username") {
                    ThemeTextField(placeholder: "e.g. user@email.com", text: $username)
                }

                formRow(label: "URL") {
                    ThemeTextField(placeholder: "https://example.com (optional)", text: $url)
                }

                // Password row
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        Text("Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .frame(width: 80, alignment: .leading)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                ThemeTextField(
                                    placeholder: "Password",
                                    text: $password,
                                    isSecure: !showPassword
                                )

                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.text3)
                                        .frame(width: 30, height: 30)
                                        .background(Theme.bgField)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                .buttonStyle(GhostButtonStyle())
                                .help(showPassword ? "Hide password" : "Show password")

                                Button {
                                    withAnimation(.spring(duration: 0.2)) {
                                        showGenerator.toggle()
                                    }
                                } label: {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(showGenerator ? Theme.accent : Theme.text3)
                                        .frame(width: 30, height: 30)
                                        .background(Theme.bgField)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                .buttonStyle(GhostButtonStyle())
                                .help("Password generator")
                            }

                            PasswordStrengthBar(password: password)

                            if showGenerator {
                                generatorPanel
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Theme.border)
                }

                formRow(label: "2FA Secret") {
                    VStack(alignment: .leading, spacing: 4) {
                        ThemeTextField(placeholder: "Base32 secret (optional)", text: $totpSecret)
                        if !totpSecret.isEmpty {
                            if TOTPGenerator.isValidSecret(totpSecret) {
                                TOTPView(secret: totpSecret, viewModel: viewModel)
                                    .padding(.top, 4)
                            } else {
                                Text("Invalid secret")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                formRow(label: "Recovery") {
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                showRecoveryCode.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showRecoveryCode ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(recoveryCode.isEmpty ? "Add recovery codes" : "Recovery codes")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Theme.text2)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        if showRecoveryCode {
                            TextEditor(text: $recoveryCode)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.text1)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .background(Theme.bgField)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                                        .stroke(Theme.border, lineWidth: 0.5)
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

                // Save button
                HStack {
                    Spacer()
                    Button { save() } label: {
                        Text(existing == nil ? "Add Entry" : "Save Changes")
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

    // MARK: - Form Row

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
            .buttonStyle(PressButtonStyle())
        }
        .padding(12)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
    }

    // MARK: - Actions

    private func save() {
        let cleanTOTP: String? = {
            guard !totpSecret.isEmpty else { return nil }
            return TOTPGenerator.isValidSecret(totpSecret) ? totpSecret : nil
        }()
        let cleanRecovery = recoveryCode.isEmpty ? nil : recoveryCode
        if var entry = existing {
            let oldPw = entry.password
            entry.siteName = siteName
            entry.username = username
            entry.password = password
            entry.url = url.isEmpty ? nil : url
            entry.notes = notes.isEmpty ? nil : notes
            entry.totpSecret = cleanTOTP
            entry.recoveryCode = cleanRecovery
            viewModel.updateEntry(entry, oldPassword: oldPw)
        } else {
            viewModel.addEntry(siteName: siteName, username: username, password: password, url: url, notes: notes, totpSecret: cleanTOTP, recoveryCode: cleanRecovery)
        }
        onClose()
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
