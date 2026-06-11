import SwiftUI

struct SummaryView: View {
    let result: SummaryResult
    let onDismiss: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.accentColor)
                        Text(bullet)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()

            HStack {
                Link("原文連結", destination: result.url)
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                Spacer()
                Button(copied ? "已複製" : "複製") {
                    UIPasteboard.general.string = formatForCopy()
                    copied = true
                }
                .font(.footnote)
                .buttonStyle(.bordered)

                Button("關閉") { onDismiss() }
                    .font(.footnote)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private func formatForCopy() -> String {
        let bulletLines = result.bullets.map { "• \($0)" }.joined(separator: "\n")
        return "\(result.title)\n\n\(bulletLines)\n\n\(result.url.absoluteString)"
    }
}
