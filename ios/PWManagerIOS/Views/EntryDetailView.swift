import SwiftUI
import PWManagerCore

struct EntryDetailView: View {
    @Bindable var viewModel: IOSVaultViewModel
    let entry: PasswordEntry
    @State private var showPassword = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showRecoveryCodes = false
    @State private var showHistory = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                row("Username", entry.username, copy: entry.username)
                row(
                    "Password",
                    showPassword ? entry.password : String(repeating: "•", count: 12),
                    copy: entry.password,
                    monospaced: true,
                    trailing: AnyView(
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(Theme.text3)
                        }
                    )
                )

                if let breach = viewModel.breachResults[entry.id] {
                    BreachStatusRow(result: breach)
                        .listRowBackground(Theme.bgCard)
                }

                if let url = entry.url, !url.isEmpty {
                    row("URL", url, copy: url)
                }
            } header: {
                Text(entry.siteName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text1)
                    .textCase(nil)
                    .padding(.leading, -16)
            }

            if let secret = entry.totpSecret, TOTPGenerator.isValidSecret(secret) {
                Section("2FA Code") {
                    TOTPCodeView(secret: secret, viewModel: viewModel)
                        .listRowBackground(Theme.bgCard)
                }
            }

            if let recovery = entry.recoveryCode, !recovery.isEmpty {
                Section("Recovery codes") {
                    Button {
                        withAnimation { showRecoveryCodes.toggle() }
                    } label: {
                        Label(
                            showRecoveryCodes ? "Hide recovery codes" : "Show recovery codes",
                            systemImage: showRecoveryCodes ? "chevron.up" : "chevron.down"
                        )
                        .foregroundStyle(Theme.accent)
                    }
                    if showRecoveryCodes {
                        VStack(alignment: .leading) {
                            Text(recovery)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.text1)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                viewModel.copyToClipboard(recovery)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.bgCard)
            }

            if let notes = entry.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text1)
                        .listRowBackground(Theme.bgCard)
                }
            }

            if !entry.history.isEmpty {
                Section {
                    Button {
                        withAnimation { showHistory.toggle() }
                    } label: {
                        Label(
                            "\(entry.history.count) previous password\(entry.history.count == 1 ? "" : "s")",
                            systemImage: showHistory ? "chevron.up" : "chevron.down"
                        )
                        .foregroundStyle(Theme.accent)
                    }
                    if showHistory {
                        ForEach(entry.history.sorted { $0.changedAt > $1.changedAt }) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.password)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Theme.text2)
                                        .lineLimit(1)
                                    Text(record.changedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.text3)
                                }
                                Spacer()
                                Button {
                                    viewModel.copyToClipboard(record.password)
                                } label: {
                                    Image(systemName: "doc.on.doc").foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Theme.bgCard)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEdit = true
                    } label: { Label("Edit", systemImage: "pencil") }
                    Button {
                        viewModel.checkBreach(for: entry)
                    } label: { Label("Re-check breach", systemImage: "shield.lefthalf.filled") }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) {
            EntryFormView(viewModel: viewModel, existing: entry)
        }
        .alert("Delete entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                viewModel.deleteEntry(id: entry.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func row(
        _ label: String,
        _ value: String,
        copy: String,
        monospaced: Bool = false,
        trailing: AnyView? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text3)
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
                    .foregroundStyle(Theme.text1)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            Spacer()
            if let trailing { trailing }
            Button {
                viewModel.copyToClipboard(copy)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Theme.accent)
            }
        }
        .listRowBackground(Theme.bgCard)
    }
}

struct TOTPCodeView: View {
    let secret: String
    let viewModel: IOSVaultViewModel
    @State private var code: String = "------"
    @State private var remaining: Int = 30

    var body: some View {
        HStack(spacing: 14) {
            Text(code.chunked(by: 3).joined(separator: " "))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.text1)
                .contentTransition(.numericText())
                .animation(.default, value: code)

            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 2)
                    .frame(width: 34, height: 34)
                Circle()
                    .trim(from: 0, to: CGFloat(remaining) / 30.0)
                    .stroke(remaining <= 5 ? Color.red : Theme.accent, lineWidth: 2)
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.95), value: remaining)
                Text("\(remaining)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(remaining <= 5 ? .red : Theme.text2)
                    .monospacedDigit()
            }

            Button {
                viewModel.copyToClipboard(code)
            } label: {
                Image(systemName: "doc.on.doc").foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
        .onAppear { tick() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                tick()
            }
        }
    }

    private func tick() {
        let now = Date().timeIntervalSince1970
        let step = 30.0
        let secondsInStep = Int(now.truncatingRemainder(dividingBy: step))
        remaining = max(1, Int(step) - secondsInStep)
        code = TOTPGenerator.generateCode(secret: secret) ?? "------"
    }
}

struct BreachStatusRow: View {
    let result: BreachResult

    var body: some View {
        HStack(spacing: 10) {
            switch result.status {
            case .breached(let count):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("Found in \(count.formatted()) breaches")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
            case .safe:
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Not in any known breach")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
            case .unknown:
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(Theme.text3)
                Text("Breach check unavailable")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text3)
            }
            Spacer()
        }
    }
}

extension String {
    func chunked(by size: Int) -> [String] {
        var result: [String] = []
        var current = ""
        for (i, c) in self.enumerated() {
            current.append(c)
            if (i + 1) % size == 0 {
                result.append(current); current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}
