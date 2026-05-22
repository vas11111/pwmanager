import SwiftUI

struct RecoveryKeyDisplayView: View {
    let recoveryKey: String
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                    .padding(.top, 24)
                Text("Save Your Recovery Key")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.text1)
                Text("This is the ONLY way to recover your vault if you lose your device or forget your PIN. Save it somewhere safe — it will not be shown again.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(recoveryKey)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.text1)
                    .textSelection(.enabled)
                    .padding(16)
                    .background(Theme.bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 24)

                Button {
                    UIPasteboard.general.string = recoveryKey
                    withAnimation(.spring(duration: 0.2)) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy Recovery Key",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("I've Saved It") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 24)
            }
            .padding()
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Recovery Key")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }
}
