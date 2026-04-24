import SwiftUI
import PWManagerCore

struct PasswordHistorySection: View {
    let history: [HistoryRecord]
    let viewModel: VaultViewModel
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 80, alignment: .leading)

                Button {
                    withAnimation(.spring(duration: 0.2)) { showHistory.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(history.count) previous password\(history.count == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text1)
                        Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.text3)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.vertical, 12)

            if showHistory {
                VStack(spacing: 0) {
                    ForEach(history) { record in
                        HStack {
                            Text(record.password)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.text2)
                                .lineLimit(1)
                                .textSelection(.enabled)
                            Spacer()
                            Text(record.changedAt, style: .relative)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.text3)
                            + Text(" ago")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.text3)

                            Button { viewModel.copyToClipboard(record.password) } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.text3)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(GhostButtonStyle())
                            .help("Copy")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.bgCard)

                        Divider().overlay(Theme.border)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                .padding(.bottom, 12)
            }

            Divider().overlay(Theme.border)
        }
    }
}
