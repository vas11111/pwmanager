import SwiftUI
import LocalAuthentication
import PWManagerCore

struct UnlockView: View {
    @Bindable var viewModel: IOSVaultViewModel
    @State private var pin = ""
    @State private var showRecovery = false

    private var biometricSymbol: String {
        switch viewModel.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Welcome Back")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.text1)
                .tracking(-0.4)

            Text("Enter your PIN to unlock.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.text2)
                .padding(.top, 6)
                .padding(.bottom, 32)

            PINPadView(
                pin: $pin,
                maxDigits: 6,
                onComplete: { viewModel.unlock(password: $0) },
                showBiometric: viewModel.canUseBiometric,
                biometricSymbol: biometricSymbol,
                onBiometric: { viewModel.unlockWithBiometrics() }
            )

            Group {
                if viewModel.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView().tint(.white)
                        Text("Unlocking...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }
                } else if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Text(" ")
                }
            }
            .frame(height: 18)
            .padding(.top, 20)

            Button("Forgot PIN? Use Recovery Key") { showRecovery = true }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text3)
                .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onChange(of: viewModel.state) { _, new in
            if new == .unlocked { pin = "" }
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if msg != nil { pin = "" }
        }
        .sheet(isPresented: $showRecovery) {
            RecoveryUnlockView(viewModel: viewModel)
        }
    }
}

struct RecoveryUnlockView: View {
    @Bindable var viewModel: IOSVaultViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryInput = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                    .padding(.top, 24)
                Text("Enter the recovery key you saved\nwhen creating your vault.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                TextField("XXXX-XXXX-XXXX-XXXX-XXXX", text: $recoveryInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 24)
                if let err = viewModel.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Button("Unlock") {
                    viewModel.unlockWithRecovery(key: recoveryInput)
                }
                .buttonStyle(.borderedProminent)
                .disabled(recoveryInput.isEmpty || viewModel.isProcessing)
                Spacer()
            }
            .padding()
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Recovery Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.state) { _, new in
                if new == .unlocked { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }
}
