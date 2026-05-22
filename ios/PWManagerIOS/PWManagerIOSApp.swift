import SwiftUI
import PWManagerCore

@main
struct PWManagerIOSApp: App {
    @State private var viewModel = IOSVaultViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .task { viewModel.checkVaultStatus() }
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    let viewModel: IOSVaultViewModel

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                ProgressView().tint(.white)
            case .needsSetup:
                CreateVaultView(viewModel: viewModel)
            case .locked:
                UnlockView(viewModel: viewModel)
            case .unlocked:
                VaultListView(viewModel: viewModel)
            }
        }
        .sheet(item: Binding(
            get: { viewModel.pendingRecoveryKey.map { RecoveryKeyWrapper(key: $0) } },
            set: { if $0 == nil { viewModel.pendingRecoveryKey = nil } }
        )) { wrapper in
            RecoveryKeyDisplayView(recoveryKey: wrapper.key) {
                viewModel.pendingRecoveryKey = nil
            }
        }
    }
}

struct RecoveryKeyWrapper: Identifiable {
    let id = UUID()
    let key: String
}
