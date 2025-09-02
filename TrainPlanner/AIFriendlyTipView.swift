import SwiftUI

struct AIFriendlyTipView: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.001) // 透明但可拦截
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.yellow.opacity(0.25), .orange.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 86, height: 86)
                    Image(systemName: "face.smiling")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                Text("我们有点没对上号 🤏")
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                Button("好的，我再试试") { onClose() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 12)
            .padding(24)
        }
        .allowsHitTesting(true)
    }
}


