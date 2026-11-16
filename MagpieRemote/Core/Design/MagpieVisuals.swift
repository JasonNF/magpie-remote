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

// MARK: - 原生系统页面背景（纯净 Apple 设计风格）
/// 遵循 iOS 26 / iOS 27 原生规范，采用系统 Grouped 语义底色，
/// 提供零 GPU 滤镜重绘开销与 120Hz 极致流畅度。
struct MagpieAuroraBackground: View {
    var body: some View {
        MagpieTheme.background
            .ignoresSafeArea()
    }

    /// 统一纯色背景
    static func safeBackground() -> some View {
        MagpieTheme.background
    }
}

// MARK: - 页面背景
extension View {
    /// 纯净 Apple 系统页面底色，保证背景无色偏且性能极致。
    func magpiePageBackground() -> some View {
        background(MagpieAuroraBackground())
    }
}

// MARK: - 标题区
/// 统一的页面头：精美 Apple 规范图标徽章 + 标题 + 一句说明。
struct MagpiePageHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String
    var tint: Color = MagpieTheme.accent

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
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
                .tracking(0.6)
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
    var size: CGFloat = 24

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.35), value: text)
            .foregroundStyle(tint.gradient)
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
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
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

