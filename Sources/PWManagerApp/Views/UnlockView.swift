import SwiftUI

struct UnlockView: View {
    let viewModel: VaultViewModel
    @State private var pin = ""
    @State private var shakeError = false
    @State private var showRecovery = false
    @State private var recoveryInput = ""
    @AppStorage("touchIDEnabled") private var touchIDEnabled = false

    private var canUseTouchID: Bool {
        // Don't gate on biometricService.isAvailable — that flag is stale after
        // recent biometric activity and would hide the button right after the
        // user just used Touch ID. Show the button whenever a password is
        // stored; the actual evaluatePolicy call inside retrievePassword will
        // surface real biometric errors at click time.
        touchIDEnabled && viewModel.biometricService.hasStoredPassword
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.04))
                .frame(width: 400, height: 400)
                .blur(radius: 120)
                .offset(y: -40)

            VStack(spacing: 0) {
                Spacer().frame(height: 10)
                cardContent
                Spacer().frame(height: 10)
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            // Refresh availability so the Touch ID button is correctly shown/hidden,
            // but DO NOT auto-fire the biometric prompt — that risks burning through
            // the system biometry lockout counter if the user steps away from the Mac.
            viewModel.biometricService.checkAvailability()
        }
        .onChange(of: viewModel.state) { _, newState in
            if newState == .unlocked { pin = "" }
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if msg != nil {
                shakeError = true
                pin = ""
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    shakeError = false
                }
            }
        }
    }

    private var cardContent: some View {
        ThemeCard(padding: 20) {
                VStack(spacing: 14) {
                    Spacer(minLength: 0)

                    VStack(spacing: 4) {
                        Text("Welcome Back")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text1)
                            .tracking(-0.4)
                        Text("Enter your PIN to unlock.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                    }

                    PINPadView(
                        pin: $pin,
                        maxDigits: 6,
                        onComplete: { completed in viewModel.unlock(password: completed) },
                        showTouchID: canUseTouchID,
                        onTouchID: { viewModel.unlockWithBiometrics() }
                    )
                    .shake(shakeError)

                    // Error / status area
                    Group {
                        if viewModel.isProcessing {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Unlocking...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.text2)
                            }
                        } else if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red)
                        } else {
                            Text(" ")
                        }
                    }
                    .frame(height: 16)

                    Group {
                        if viewModel.remainingAttempts > 0 && viewModel.remainingAttempts < 10 {
                            Text("\(viewModel.remainingAttempts) attempts remaining")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.text3)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 14)

                    Button("Forgot PIN? Use Recovery Key") {
                        showRecovery = true
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
            .sheet(isPresented: $showRecovery) {
                RecoveryUnlockView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .frame(width: 400)
            .frame(maxHeight: .infinity)
    }
}
