import SwiftUI
import PWManagerCore

struct EntryFormView: View {
    @Bindable var viewModel: IOSVaultViewModel
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
    @State private var genCustomSymbols = false
    @State private var genCustomSymbolSet = PasswordGenerator.CharacterSet.defaultSymbols
    @State private var copyJustHit = false

    init(viewModel: IOSVaultViewModel, existing: PasswordEntry?) {
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
        NavigationStack {
            Form {
                Section("Site") {
                    TextField("Site name", text: $siteName)
                    TextField("Username or email", text: $username)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                Section("Password") {
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Password", text: $password)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        Button {
                            guard !password.isEmpty else { return }
                            viewModel.copyToClipboard(password)
                            withAnimation(.spring(duration: 0.15)) { copyJustHit = true }
                            Task {
                                try? await Task.sleep(for: .seconds(1.2))
                                withAnimation { copyJustHit = false }
                            }
                        } label: {
                            Image(systemName: copyJustHit ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(copyJustHit ? .green : Theme.accent)
                        }
                        .disabled(password.isEmpty)
                    }
                    Button {
                        withAnimation { showGenerator.toggle() }
                    } label: {
                        Label(showGenerator ? "Hide generator" : "Generate password", systemImage: "wand.and.stars")
                    }
                    if showGenerator {
                        generatorSection
                    }
                }
                Section("Optional") {
                    TextField("URL", text: $url)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle(existing == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    @ViewBuilder private var generatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Length: \(Int(genLength))").monospacedDigit().frame(width: 90, alignment: .leading)
                Slider(value: $genLength, in: 8...64, step: 1).tint(Theme.accent)
            }
            Toggle("a–z", isOn: $genLowercase)
            Toggle("A–Z", isOn: $genUppercase)
            Toggle("0–9", isOn: $genDigits)
            Toggle("Symbols", isOn: $genSymbols)
            if genSymbols {
                Toggle("Restrict symbol set", isOn: $genCustomSymbols)
                if genCustomSymbols {
                    TextField("Allowed symbols", text: $genCustomSymbolSet)
                        .font(.system(.caption, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Text("Only these symbols will be used. Delete the ones the site doesn't allow.")
                        .font(.caption2)
                        .foregroundStyle(Theme.text3)
                }
            }
            HStack(spacing: 8) {
                Button {
                    password = generate()
                    showGenerator = false
                    showPassword = true
                } label: {
                    Text("Generate & Fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    let g = generate()
                    password = g
                    showPassword = true
                    viewModel.copyToClipboard(g)
                } label: {
                    Text("Generate & Copy").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func generate() -> String {
        var sets: [PasswordGenerator.CharacterSet] = []
        if genLowercase { sets.append(.lowercase) }
        if genUppercase { sets.append(.uppercase) }
        if genDigits { sets.append(.digits) }
        if genSymbols {
            if genCustomSymbols && !genCustomSymbolSet.isEmpty {
                sets.append(.customSymbols(genCustomSymbolSet))
            } else {
                sets.append(.symbols)
            }
        }
        if sets.isEmpty { sets = [.lowercase, .uppercase, .digits] }
        return PasswordGenerator.generate(length: Int(genLength), using: sets)
    }

    private func save() {
        if var entry = existing {
            let oldPw = entry.password
            entry.siteName = siteName
            entry.username = username
            entry.password = password
            entry.url = url.isEmpty ? nil : url
            entry.notes = notes.isEmpty ? nil : notes
            viewModel.updateEntry(entry, oldPassword: oldPw)
        } else {
            viewModel.addEntry(
                siteName: siteName, username: username, password: password,
                url: url, notes: notes
            )
        }
        dismiss()
    }
}
