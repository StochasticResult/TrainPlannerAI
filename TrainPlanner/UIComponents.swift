import SwiftUI

// 已移除：AI 建议 Chip

// 公共：柔和散景背景（用于卡片底层装饰）
public struct BokehBackground: View {
    let base: Color
    let animated: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(base: Color, animated: Bool = true) { self.base = base; self.animated = animated }
    public var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ZStack { backgroundLayers(t) }
                }
            } else {
                ZStack { backgroundLayers(nil) }
            }
        }
        .clipped()
    }
    @ViewBuilder
    private func backgroundLayers(_ time: TimeInterval?) -> some View {
        let g1 = (scheme == .dark) ? 0.06 : 0.10
        let g2 = (scheme == .dark) ? 0.02 : 0.04
        LinearGradient(colors: [base.opacity(g1), base.opacity(g2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        let o1 = (scheme == .dark) ? 0.20 : 0.28
        let o2 = (scheme == .dark) ? 0.16 : 0.22
        let o3 = (scheme == .dark) ? 0.12 : 0.18
        let m1 = offset(time, sx: 8, sy: 6, fx: 1/6.0, fy: 1/7.0)
        let m2 = offset(time, sx: 6, sy: 5, fx: 1/5.5, fy: 1/6.5)
        let m3 = offset(time, sx: 10, sy: 8, fx: 1/7.5, fy: 1/8.5)
        BokehBlob(color: base.opacity(o1), size: 160, x: -60 + m1.x, y: -40 + m1.y, blur: 28)
        BokehBlob(color: base.opacity(o2), size: 120, x: 90 + m2.x, y: -20 + m2.y, blur: 24)
        BokehBlob(color: base.opacity(o3), size: 200, x: 40 + m3.x, y: 80 + m3.y, blur: 30)
    }
    private func offset(_ t: TimeInterval?, sx: CGFloat, sy: CGFloat, fx: Double, fy: Double) -> (x: CGFloat, y: CGFloat) {
        guard let t = t else { return (0, 0) }
        let dx = sin(t * fx) * Double(sx)
        let dy = cos(t * fy) * Double(sy)
        return (CGFloat(dx), CGFloat(dy))
    }
}

// 公共：空态插画（渐变几何）
public struct EmptyIllustrationView: View {
    let theme: Color
    public init(theme: Color) { self.theme = theme }
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [theme.opacity(0.12), theme.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(theme.opacity(0.22)).frame(width: 72, height: 72).blur(radius: 2)
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(theme)
                }
                Text(L("ui.empty_tasks"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .frame(height: 132)
    }
}

// 已移除：AI 建议短语池

// 已移除：AI 建议管理器

extension DateFormatter {
    static let cachedYMD: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; return f
    }()
}

struct BokehBlob: View {
    let color: Color
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let blur: CGFloat
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: blur)
            .offset(x: x, y: y)
    }
}

// MARK: - 新 UI 组件

// 环绕卡片的进度描边
public struct CardBorderProgress: View {
    let ratio: Double
    let color: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    public init(ratio: Double, color: Color, cornerRadius: CGFloat = 16, lineWidth: CGFloat = 6) {
        self.ratio = min(max(ratio, 0), 1)
        self.color = color
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
    }
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            RoundedRectangle(cornerRadius: cornerRadius)
                .trim(from: 0, to: ratio)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

public struct BigNumberCard: View {
    let title: String
    let valueText: String
    let subtitle: String
    let ratio: Double
    let color: Color
    public init(title: String, valueText: String, subtitle: String, ratio: Double, color: Color) {
        self.title = title
        self.valueText = valueText
        self.subtitle = subtitle
        self.ratio = ratio
        self.color = color
    }
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
            CardBorderProgress(ratio: ratio, color: color, cornerRadius: 16, lineWidth: 8)
                .padding(2)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(valueText).font(.system(size: 32, weight: .bold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: "flame.fill").foregroundStyle(color)
                }
            }
            .padding(16)
        }
    }
}

public struct MacroMiniCard: View {
    let title: String
    let valueText: String
    let ratio: Double
    let color: Color
    let systemImage: String
    public init(title: String, valueText: String, ratio: Double, color: Color, systemImage: String) {
        self.title = title
        self.valueText = valueText
        self.ratio = ratio
        self.color = color
        self.systemImage = systemImage
    }
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.06), lineWidth: 1))
            CardBorderProgress(ratio: ratio, color: color, cornerRadius: 14, lineWidth: 6)
                .padding(2)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(color.opacity(0.12)).frame(width: 22, height: 22)
                    Image(systemName: systemImage).foregroundStyle(color)
                }
                Text(valueText).font(.headline)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


