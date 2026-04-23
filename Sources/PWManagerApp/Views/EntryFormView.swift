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
            // Title bar
            Text(existing == nil ? "New Entry" : "Edit Entry")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.bar)

            Divider()

            Form {
                Section {
                    TextField("Site Name", text: $siteName)
                    TextField("Username or Email", text: $username)
                    TextField("URL", text: $url)
                        .textContentType(.URL)
                }

                Section {
                    HStack(spacing: 8) {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .fontDesign(.monospaced)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .frame(minWidth: 200)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .frame(width: 18)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showGenerator.toggle()
                            }
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .frame(width: 18)
                        }
                        .buttonStyle(.borderless)
                        .help("Password generator")
                    }

                    if showGenerator {
                        generatorControls
                    }
                } header: {
                    Text("Password")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 72)
                        .font(.body)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Add Entry" : "Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 460, height: 520)
    }

    private var generatorControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Length: \(Int(genLength))")
                    .font(.callout)
                    .monospacedDigit()
                    .frame(width: 70, alignment: .leading)
                Slider(value: $genLength, in: 8...64, step: 1)
            }

            HStack(spacing: 16) {
                Toggle("a-z", isOn: $genLowercase)
                Toggle("A-Z", isOn: $genUppercase)
                Toggle("0-9", isOn: $genDigits)
                Toggle("#$%", isOn: $genSymbols)
            }
            .toggleStyle(.checkbox)
            .font(.callout)

            Button {
                password = generatePassword()
                showGenerator = false
                showPassword = true
            } label: {
                Text("Generate & Fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
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
