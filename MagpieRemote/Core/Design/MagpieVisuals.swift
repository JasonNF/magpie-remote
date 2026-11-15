import SwiftUI

// MARK: - 嵌入导航
/// 让同一个页面既能作为 Tab 根（自带 NavigationStack），
/// 也能被「更多」的导航栈推入（复用外层栈，避免嵌套导航栏）。
private struct MagpieEmbeddedNavigationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var magpieEmbeddedNavigation: Bool {
        get { self[MagpieEmbeddedNavigationKey.self] }
        set { self[MagpieEmbeddedNavigationKey.self] = newValue }
    }
}

struct MagpieNavigationContainer<Content: View>: View {
    @Environment(\.magpieEmbeddedNavigation) private var embedded
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if embedded {
            content()
        } else {
            NavigationStack {
                content()
            }
        }
    }
}

// MARK: - 极光背景
/// 全局流动极光背景：低饱和的品牌色光晕在页面背后缓慢漂移，
/// 为原生组件提供层次感与“活”的观感，同时尊重「减弱动态效果」。
/// 性能优先：静态光晕 + 一次性的柔和位移动画，避免常驻 repeatForever 拖慢 GPU。
struct MagpieAuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        Group {
            if reduceMotion {
                MagpieTheme.background
            } else {
                aurora
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            // 一次性到位，不再 repeatForever：保留层次感并大幅降低持续成本
            withAnimation(.easeInOut(duration: 8)) {
                drift = true
            }
        }
    }

    private var aurora: some View {
        ZStack {
            MagpieTheme.background

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                Circle()
                    .fill(MagpieTheme.accent.opacity(colorScheme == .dark ? 0.26 : 0.15))
                    .frame(width: w * 1.05)
                    .blur(radius: 90)
                    .offset(x: drift ? -w * 0.30 : w * 0.12,
                            y: drift ? -h * 0.18 : -h * 0.04)

                Circle()
                    .fill(MagpieTheme.cyan.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    .frame(width: w * 0.9)
                    .blur(radius: 100)
                    .offset(x: drift ? w * 0.30 : -w * 0.28,
                            y: drift ? h * 0.10 : h * 0.28)

                Circle()
                    .fill(Color(hex: "ec4899").opacity(colorScheme == .dark ? 0.12 : 0.07))
                    .frame(width: w * 0.75)
                    .blur(radius: 110)
                    .offset(x: drift ? -w * 0.08 : w * 0.34,
                            y: drift ? h * 0.36 : h * 0.16)
            }
            .allowsHitTesting(false)
        }
    }

    /// Reduce Motion 下使用纯色背景，彻底省去 blur 开销。
    static func safeBackground() -> some View {
        MagpieTheme.background
    }
}

// MARK: - 页面背景
extension View {
    /// 以极光背景替换纯色页面底色；Reduce Motion 时由背景自身退回纯色。
    func magpiePageBackground() -> some View {
        background(MagpieAuroraBackground())
    }
}

// MARK: - 标题区
/// 统一的页面头：渐变图标徽章 + 标题 + 一句说明。
struct MagpiePageHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String
    var tint: Color = MagpieTheme.accent

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: tint.opacity(0.35), radius: 12, x: 0, y: 6)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MagpieTheme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 分组标题
struct MagpieSectionLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MagpieTheme.textMuted)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted.opacity(0.85))
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 渐变数值
/// 大号数字使用圆角等宽字形与渐变填充，作为仪表盘的视觉焦点。
struct MagpieGradientNumber: View {
    let text: String
    var tint: Color = MagpieTheme.accent
    var size: CGFloat = 26

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.35), value: text)
            .foregroundStyle(
                LinearGradient(
                    colors: [tint, tint.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }
}

// MARK: - 状态胶囊
struct MagpieStatusChip: View {
    let text: String
    var color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.13))
        .foregroundStyle(color)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 0.5))
    }
}

// MARK: - 主按钮（原生 Liquid Glass）
struct MagpiePrimaryButtonStyle: ButtonStyle {
    var tint: Color = MagpieTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(tint.gradient, in: Capsule())
            .magpieLiquidSurface(cornerRadius: 999, tint: tint, interactive: true)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1, anchor: .center)
            .animation(.spring(response: 0.26, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 卡片按压反馈（统一锚点，避免偏移）
struct MagpiePressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1, anchor: .center)
            .opacity(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

