import SwiftUI
import PWManagerCore

/// Presented from either Settings (export) or CreateVault (restore).
struct ICloudBackupsView: View {
    enum Mode {
        case restore  // Pick a backup to restore (no existing vault)
        case manage   // Browse backups; can save or delete
    }

    @Bindable var viewModel: IOSVaultViewModel
    let mode: Mode
    @Environment(\.dismiss) private var dismiss

    @State private var store = ICloudBackupStore()
    @State private var loading = false
    @State private var selectedBackup: ICloudBackupStore.BackupFile?
    @State private var importingData: Data?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if !store.isAvailable {
                    notAvailableView
                } else if store.backups.isEmpty {
                    emptyView
                } else {
                    backupList
                }
            }
            .background(Theme.bg)
            .navigationTitle("iCloud Backups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.refresh() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear { store.refresh() }
            .alert("Error", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .sheet(item: Binding(
                get: { importingData.map { BackupBlob(data: $0) } },
                set: { if $0 == nil { importingData = nil } }
            )) { blob in
                ImportBackupFlow(viewModel: viewModel, backupData: blob.data)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    private var notAvailableView: some View {
        VStack(spacing: 18) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 44))
                .foregroundStyle(Theme.text3)
            Text("iCloud Drive not available")
                .font(.system(size: 17, weight: .semibold))
            Text("Sign in to iCloud and enable iCloud Drive in Settings → Apple ID → iCloud → iCloud Drive.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "icloud")
                .font(.system(size: 44))
                .foregroundStyle(Theme.text3)
            Text("No backups in iCloud yet")
                .font(.system(size: 17, weight: .semibold))
            Text(mode == .restore
                 ? "Export a backup from another device or drop a .pwmbackup file into the PWManager folder in iCloud Drive."
                 : "Tap Export to create your first iCloud backup.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backupList: some View {
        List {
            Section {
                ForEach(store.backups) { backup in
                    Button { tap(backup) } label: {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.text1)
                                    .lineLimit(1)
                                Text("\(backup.modifiedAt.formatted(date: .abbreviated, time: .shortened)) · \(format(backup.size))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text3)
                            }
                            Spacer()
                            if loading && selectedBackup?.id == backup.id {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.text3)
                            }
                        }
                    }
                    .listRowBackground(Theme.bgCard)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.delete(backup)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } header: {
                Text(mode == .restore ? "Tap a backup to restore" : "Backups in PWManager folder")
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func tap(_ backup: ICloudBackupStore.BackupFile) {
        guard mode == .restore else { return }
        selectedBackup = backup
        loading = true
        Task {
            do {
                let data = try await store.ensureDownloaded(backup)
                loading = false
                selectedBackup = nil
                importingData = data
            } catch {
                loading = false
                selectedBackup = nil
                errorText = "Couldn't load backup: \(error.localizedDescription)"
            }
        }
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct BackupBlob: Identifiable {
    let id = UUID()
    let data: Data
}
