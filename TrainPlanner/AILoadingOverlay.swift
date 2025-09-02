import SwiftUI

struct AILoadingOverlay: View {
    let text: String
    let onCancel: () -> Void

    @State private var spin = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            // 透明层：让主界面可见，同时拦截交互
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            // 渐变“能量球”
            Circle()
                .fill(AngularGradient(colors: [
                    Color.blue.opacity(0.35),
                    Color.purple.opacity(0.35),
                    Color.cyan.opacity(0.35),
                    Color.blue.opacity(0.35)
                ], center: .center))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .scaleEffect(1.02)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: spin)

            // 自定义环形进度（更精致的旋转）
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.98)
                    .stroke(AngularGradient(colors: [.white.opacity(0.8), .white.opacity(0.2)], center: .center), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 1.15).repeatForever(autoreverses: false), value: spin)

                Circle()
                    .fill(LinearGradient(colors: [.white, .white.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 10, height: 10)
                    .offset(y: -52)
                    .rotationEffect(.degrees(orbit ? 360 : 0))
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: orbit)
            }
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

            // 文案 + 取消
            VStack(spacing: 10) {
                Spacer().frame(height: 150)
                Text(text)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                Button(role: .cancel) { onCancel() } label: {
                    Text("取消").font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .onAppear { spin = true; orbit = true }
        .allowsHitTesting(true) // 拦截所有交互，仅允许点击取消
    }
}


