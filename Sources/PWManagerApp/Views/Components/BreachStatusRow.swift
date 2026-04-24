import SwiftUI
import PWManagerCore

struct BreachStatusRow: View {
    let entry: PasswordEntry
    let viewModel: VaultViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Security")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)

                if let result = viewModel.breachResults[entry.id] {
                    if result.isBreached {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 12))
                            Text("Found in \(result.occurrences.formatted()) breaches")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    } else if result.isUnknown {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12))
                            Text("Unable to check")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                            Text("No breaches found")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Checking...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.text3)
                    }
                }

                Spacer()

                Button {
                    viewModel.checkBreach(for: entry)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.text3)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(GhostButtonStyle())
                .help("Recheck")
            }
            .padding(.vertical, 12)

            Divider().overlay(Theme.border)
        }
        .onAppear { viewModel.checkBreach(for: entry) }
    }
}
