import SwiftUI
import AppKit

struct RecoveryKeyView: View {
    let recoveryKey: String
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 68, height: 68)
                        Image(systemName: "key.horizontal.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.orange)
                    }

                    VStack(spacing: 6) {
                        Text("Your Recovery Key")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.text1)

                        Text("Write this down and store it somewhere safe.\nYou'll need it if you forget your PIN.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    // Recovery key display
                    VStack(spacing: 8) {
                        Text(recoveryKey)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.text1)
                            .textSelection(.enabled)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Theme.bgField)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.r, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 0.5)
                            )

                        Button {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(recoveryKey, forType: .string)
                            pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
                            let changeCount = pb.changeCount
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(30))
                                if pb.changeCount == changeCount { pb.clearContents() }
                            }
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied!" : "Copy to Clipboard")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    // Warning
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("This is the only time you'll see this key.")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("If you lose both your PIN and recovery key, your vault cannot be recovered.")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.text2)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r, style: .continuous))
                }
                .padding(32)
            }

            Divider().overlay(Theme.border)

            Button {
                onDismiss()
            } label: {
                Text("I've Saved My Recovery Key")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(AccentButtonStyle())
            .padding(20)
        }
        .frame(width: 440, height: 520)
        .background(Theme.bg)
    }
}
