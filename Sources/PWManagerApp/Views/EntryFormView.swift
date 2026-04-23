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
            Form {
                Section("Details") {
                    TextField("Site Name", text: $siteName)
                    TextField("Username", text: $username)
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                }

                Section("Password") {
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .fontDesign(.monospaced)
                        } else {
                            SecureField("Password", text: $password)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)

                        Button("Generate") {
                            showGenerator.toggle()
                        }
                        .buttonStyle(.borderless)
                    }

                    if showGenerator {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Length: \(Int(genLength))")
                                    .monospacedDigit()
                                Slider(value: $genLength, in: 8...64, step: 1)
                            }
                            HStack(spacing: 12) {
                                Toggle("abc", isOn: $genLowercase)
                                Toggle("ABC", isOn: $genUppercase)
                                Toggle("123", isOn: $genDigits)
                                Toggle("#$%", isOn: $genSymbols)
                            }
                            .toggleStyle(.checkbox)

                            Button("Fill Password") {
                                password = generatePassword()
                                showGenerator = false
                                showPassword = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                        .font(.body)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Add Entry" : "Save Changes") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 440)
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
