import SwiftUI

struct RecoveryUnlockView: View {
    let viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryInput = ""
    @State private var shakeError = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recovery Key")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.text3)
                        .frame(width: 22, height: 22)
                        .background(Theme.bgField)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().overlay(Theme.border)

            VStack(spacing: 16) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.top, 20)

                Text("Enter the recovery key you saved\nwhen creating your vault.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)

                ThemeTextField(
                    placeholder: "XXXX-XXXX-XXXX-XXXX-XXXX",
                    text: $recoveryInput
                )
                .padding(.horizontal, 20)
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
                .frame(height: 14)

                Button {
                    viewModel.unlockWithRecovery(key: recoveryInput)
                } label: {
                    Text("Unlock with Recovery Key")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 200)
                }
                .buttonStyle(AccentButtonStyle(disabled: recoveryInput.isEmpty || viewModel.isProcessing))
                .disabled(recoveryInput.isEmpty || viewModel.isProcessing)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 360, height: 300)
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
