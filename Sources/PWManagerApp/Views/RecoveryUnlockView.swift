import SwiftUI
import PWManagerCore

struct RecoveryUnlockView: View {
    let viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryInput = ""
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recovery Key")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.text3)
                        .frame(width: 26, height: 26)
                        .background(Theme.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider().overlay(Theme.border)

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.orange)

                Text("Enter the recovery key you saved when creating your vault.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                ThemeTextField(
                    placeholder: "XXXX-XXXX-XXXX-XXXX-XXXX",
                    text: $recoveryInput
                )
                .padding(.horizontal, 24)
                .shake(shakeError)

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

                Button {
                    viewModel.unlockWithRecovery(key: recoveryInput)
                } label: {
                    Text("Unlock with Recovery Key")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 220)
                }
                .buttonStyle(AccentButtonStyle(disabled: recoveryInput.isEmpty || viewModel.isProcessing))
                .disabled(recoveryInput.isEmpty || viewModel.isProcessing)

                Spacer()
            }
        }
        .frame(width: 420, height: 400)
        .background(Theme.bg)
        .onChange(of: viewModel.state) { _, newState in
            if newState == .unlocked { dismiss() }
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if msg != nil {
                shakeError = true
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    shakeError = false
                }
            }
        }
    }
}
