import SwiftUI

/// magpie 官方 iOS 原生视觉规范与主题色板。
/// 全面遵循 iOS 26 / iOS 27 Apple Human Interface Guidelines 规范，
/// 采用原生语义色彩、系统分组层次与 Liquid Glass 质感，保证 120Hz 零掉帧流畅性。
enum MagpieTheme {
    // MARK: - 背景与卡片（Apple 系统分组层次）
    /// 系统分组背景：浅色 SystemGroupedBackground，深色 SecondarySystemBackground
    static let background = Color(uiColor: .systemGroupedBackground)

    /// 系统卡片背景：浅色 SecondarySystemGroupedBackground（纯白），深色 SecondarySystemGroupedBackground（深灰）
    static let card = Color(uiColor: .secondarySystemGroupedBackground)

    /// 嵌套卡片 / 展开面板：TertiarySystemGroupedBackground
    static let cardSecondary = Color(uiColor: .tertiarySystemGroupedBackground)

    /// 胶囊 / 搜索框底色：TertiarySystemFill
    static let pill = Color(uiColor: .tertiarySystemFill)

    /// 边框分隔线：Separator 微透明
    static let border = Color(uiColor: .separator).opacity(0.35)

    /// 次级细微边框线
    static let borderSubtle = Color(uiColor: .separator).opacity(0.18)

    // MARK: - 文字（系统语义层级）
    /// 主文字：Label / Primary
    static let textPrimary = Color.primary

    /// 次级文字：SecondaryLabel / Secondary
    static let textSecondary = Color.secondary

    /// 提示/弱化文字：TertiaryLabel
    static let textMuted = Color(uiColor: .tertiaryLabel)

    // MARK: - 强调色与状态色（Apple 原生动态系统色彩）
    /// 主强调色：Indigo
    static let accent = Color(uiColor: .systemIndigo)

    /// 强调色淡雅底色
    static let accentSoft = Color(uiColor: .systemIndigo).opacity(0.12)

    /// 成功 / 活跃状态：SystemGreen
    static let green = Color(uiColor: .systemGreen)
    static let greenSoft = Color(uiColor: .systemGreen).opacity(0.12)

    /// 漂移 / 警告状态：SystemOrange
    static let drift = Color(uiColor: .systemOrange)
    static let driftSoft = Color(uiColor: .systemOrange).opacity(0.12)

    /// 警告：SystemOrange
    static let amber = Color(uiColor: .systemOrange)
    static let amberSoft = Color(uiColor: .systemOrange).opacity(0.12)

    /// 危险 / 离线：SystemRed
    static let red = Color(uiColor: .systemRed)
    static let redSoft = Color(uiColor: .systemRed).opacity(0.12)

    /// 紫色 (Token 输出 / Rotate 策略)：SystemPurple
    static let purple = Color(uiColor: .systemPurple)
    /// 青色 (Token 缓存 / Smart 策略)：SystemTeal
    static let cyan = Color(uiColor: .systemTeal)
    /// 粉色 (Pace 策略)：SystemPink
    static let pink = Color(uiColor: .systemPink)
}

// MARK: - View 扩展辅助
extension View {
    /// 现代玻璃卡片：iOS 26/27 原生 Liquid Glass；旧系统回退材质。
    func magpieCard(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .magpieLiquidSurface(cornerRadius: cornerRadius)
    }

    /// 现代 Apple 风格流动玻璃质感卡片（Liquid Glass）。
    func magpieGlass(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .magpieLiquidSurface(cornerRadius: cornerRadius)
    }

    /// 原版小芯片（Chip）胶囊背景（iOS 26/27 触觉与微质感）。
    func magpieChip(isSelected: Bool = false) -> some View {
        self
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? MagpieTheme.accent.opacity(0.18) : MagpieTheme.pill)
            .foregroundStyle(isSelected ? MagpieTheme.accent : MagpieTheme.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? MagpieTheme.accent.opacity(0.4) : MagpieTheme.borderSubtle, lineWidth: 0.8)
            )
    }

    /// 让 List 透出背景（毛玻璃观感 + 性能）。
    func magpieListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
    }
}

// MARK: - 触觉反馈安全封装
@MainActor
enum MagpieHaptics {
    static func light() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func medium() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

// MARK: - 呼吸光点指示器 (固定 14×14 布局边界，扩散光环不参与布局)
/// 光环的无限循环交给 Core Animation 在渲染进程里播放，外观与原先的 SwiftUI
/// `repeatForever` 一致；但 SwiftUI 的无限动画会让 App 主线程每帧重新计算视图，
/// 页面上多个状态点同时呼吸时会持续占用 CPU、导致发热。
struct MagpiePulseDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // 中心固定实心小圆
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            if !reduceMotion {
                MagpiePulseRing(color: UIColor(color.opacity(0.55)), isActive: scenePhase == .active)
                    .frame(width: 14, height: 14)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 14, height: 14)
    }
}

/// 7pt 描边圆环从 1.0 倍放大到 2.1 倍并淡出，1.4 秒 easeOut 一轮，无限循环。
struct MagpiePulseRing: UIViewRepresentable {
    let color: UIColor
    var isActive: Bool = true

    func makeUIView(context: Context) -> MagpiePulseRingView {
        MagpiePulseRingView()
    }

    func updateUIView(_ view: MagpiePulseRingView, context: Context) {
        view.ringColor = color
        view.setAnimating(isActive)
    }
}

final class MagpiePulseRingView: UIView {
    static let duration: CFTimeInterval = 1.4
    private static let animationKey = "magpie.pulse"

    private let ring = CAShapeLayer()
    private var wantsAnimation = true

    var ringColor: UIColor = .systemGreen {
        didSet { applyColor() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 1.2
        ring.opacity = 0
        layer.addSublayer(ring)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let diameter: CGFloat = 7
        ring.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        ring.position = CGPoint(x: bounds.midX, y: bounds.midY)
        // 与 SwiftUI 的 Circle().stroke 一致：描边居中压在 7pt 圆的边线上
        ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
        installAnimationIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installAnimationIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColor()
    }

    func setAnimating(_ animating: Bool) {
        guard animating != wantsAnimation else { return }
        wantsAnimation = animating
        if animating {
            installAnimationIfNeeded()
        } else {
            ring.removeAnimation(forKey: Self.animationKey)
        }
    }

    private func applyColor() {
        ring.strokeColor = ringColor.resolvedColor(with: traitCollection).cgColor
    }

    /// 不在窗口里（切到其他页面）时不挂动画，回到窗口再挂上。
    private func installAnimationIfNeeded() {
        guard wantsAnimation, window != nil, ring.animation(forKey: Self.animationKey) == nil else { return }
        applyColor()

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 2.1

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.85
        fade.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false
        ring.add(group, forKey: Self.animationKey)
    }
}

// MARK: - Color Hex 支持
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
