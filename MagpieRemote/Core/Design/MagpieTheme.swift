import SwiftUI

/// magpie 官方 Web / Desktop 原生视觉规范与主题色板。
/// 支持浅色（Light）与深色（Dark）模式完全对齐原版 CSS 变量，融合 Apple Liquid Glass 现代美学。
enum MagpieTheme {
    // MARK: - 背景与卡片
    /// --bg: 浅色 #f4f4f6，深色 #1a1a1e
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1e/255.0, alpha: 1.0)
            : UIColor(red: 0xf4/255.0, green: 0xf4/255.0, blue: 0xf6/255.0, alpha: 1.0)
    })

    /// --card: 浅色 #ffffff，深色 #232327
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x23/255.0, green: 0x23/255.0, blue: 0x27/255.0, alpha: 1.0)
            : UIColor(red: 0xff/255.0, green: 0xff/255.0, blue: 0xff/255.0, alpha: 1.0)
    })

    /// --card-2: 展开编辑器/嵌套面板 浅色 #f9f9fb，深色 #1f1f23
    static let cardSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x1f/255.0, green: 0x1f/255.0, blue: 0x23/255.0, alpha: 1.0)
            : UIColor(red: 0xf9/255.0, green: 0xf9/255.0, blue: 0xfb/255.0, alpha: 1.0)
    })

    /// --pill: 浅色 #f1f1f4，深色 #2d2d33
    static let pill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2d/255.0, green: 0x2d/255.0, blue: 0x33/255.0, alpha: 1.0)
            : UIColor(red: 0xf1/255.0, green: 0xf1/255.0, blue: 0xf4/255.0, alpha: 1.0)
    })

    /// --line: 边框线 浅色 #e3e3e8，深色 #333339
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x33/255.0, green: 0x33/255.0, blue: 0x39/255.0, alpha: 1.0)
            : UIColor(red: 0xe3/255.0, green: 0xe3/255.0, blue: 0xe8/255.0, alpha: 1.0)
    })

    /// --line-2: 次级分隔线 浅色 #ececf0，深色 #2c2c32
    static let borderSubtle = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2c/255.0, green: 0x2c/255.0, blue: 0x32/255.0, alpha: 1.0)
            : UIColor(red: 0xec/255.0, green: 0xec/255.0, blue: 0xf0/255.0, alpha: 1.0)
    })

    // MARK: - 文字
    /// --fg: 主文字 浅色 #1c1c21，深色 #ededf1
    static let textPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xed/255.0, green: 0xed/255.0, blue: 0xf1/255.0, alpha: 1.0)
            : UIColor(red: 0x1c/255.0, green: 0x1c/255.0, blue: 0x21/255.0, alpha: 1.0)
    })

    /// --fg-2: 次级文字 浅色 #4b4b53，深色 #b9b9c1
    static let textSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xb9/255.0, green: 0xb9/255.0, blue: 0xc1/255.0, alpha: 1.0)
            : UIColor(red: 0x4b/255.0, green: 0x4b/255.0, blue: 0x53/255.0, alpha: 1.0)
    })

    /// --muted: 提示文字 浅色 #85858d，深色 #8b8b94
    static let textMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x8b/255.0, green: 0x8b/255.0, blue: 0x94/255.0, alpha: 1.0)
            : UIColor(red: 0x85/255.0, green: 0x85/255.0, blue: 0x8d/255.0, alpha: 1.0)
    })

    // MARK: - 强调色与状态色
    /// --accent: 官方主强调色 浅色 #4f46e5 (Indigo)，深色 #a5b4fc
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xa5/255.0, green: 0xb4/255.0, blue: 0xfc/255.0, alpha: 1.0)
            : UIColor(red: 0x4f/255.0, green: 0x46/255.0, blue: 0xe5/255.0, alpha: 1.0)
    })

    /// --accent-soft: 强调色浅底
    static let accentSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2b/255.0, green: 0x2c/255.0, blue: 0x47/255.0, alpha: 1.0)
            : UIColor(red: 0xee/255.0, green: 0xed/255.0, blue: 0xfd/255.0, alpha: 1.0)
    })

    /// --green: 已接入 / 活跃状态 浅色 #189a58，深色 #6fd99b
    static let green = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x6f/255.0, green: 0xd9/255.0, blue: 0x9b/255.0, alpha: 1.0)
            : UIColor(red: 0x18/255.0, green: 0x9a/255.0, blue: 0x58/255.0, alpha: 1.0)
    })
    static let greenSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x1e/255.0, green: 0x3a/255.0, blue: 0x2b/255.0, alpha: 1.0)
            : UIColor(red: 0xe4/255.0, green: 0xf6/255.0, blue: 0xec/255.0, alpha: 1.0)
    })

    /// --drift: 配置被外部改写（漂移） 浅色 #ce2c31，深色 #ff9592
    static let drift = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xff/255.0, green: 0x95/255.0, blue: 0x92/255.0, alpha: 1.0)
            : UIColor(red: 0xce/255.0, green: 0x2c/255.0, blue: 0x31/255.0, alpha: 1.0)
    })
    static let driftSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x3b/255.0, green: 0x12/255.0, blue: 0x19/255.0, alpha: 1.0)
            : UIColor(red: 0xfe/255.0, green: 0xeb/255.0, blue: 0xec/255.0, alpha: 1.0)
    })

    /// --amber: 警告/旧副本 浅色 #b45309，深色 #f2b544
    static let amber = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xf2/255.0, green: 0xb5/255.0, blue: 0x44/255.0, alpha: 1.0)
            : UIColor(red: 0xb4/255.0, green: 0x53/255.0, blue: 0x09/255.0, alpha: 1.0)
    })
    static let amberSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x3f/255.0, green: 0x32/255.0, blue: 0x20/255.0, alpha: 1.0)
            : UIColor(red: 0xfb/255.0, green: 0xf0/255.0, blue: 0xdf/255.0, alpha: 1.0)
    })

    /// --red: 错误/未连接 浅色 #d64545，深色 #f28b82
    static let red = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xf2/255.0, green: 0x8b/255.0, blue: 0x82/255.0, alpha: 1.0)
            : UIColor(red: 0xd6/255.0, green: 0x45/255.0, blue: 0x45/255.0, alpha: 1.0)
    })
    static let redSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x45/255.0, green: 0x27/255.0, blue: 0x2a/255.0, alpha: 1.0)
            : UIColor(red: 0xfb/255.0, green: 0xe9/255.0, blue: 0xe9/255.0, alpha: 1.0)
    })

    /// 紫色 (Token 输出 / Rotate 策略)
    static let purple = Color(hex: "8b5cf6")
    /// 青色 (Token 缓存 / Smart 策略)
    static let cyan = Color(hex: "06b6d4")
    /// 粉色 (Pace 策略)
    static let pink = Color(hex: "ec4899")
}

// MARK: - View 扩展辅助
extension View {
    /// 现代玻璃卡片：iOS 26 原生 Liquid Glass；旧系统回退材质。
    func magpieCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .magpieLiquidSurface(cornerRadius: cornerRadius)
    }

    /// 现代 Apple 风格流动玻璃质感卡片（Liquid Glass）。
    func magpieGlass(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .magpieLiquidSurface(cornerRadius: cornerRadius)
    }

    /// 原版小芯片（Chip）胶囊背景。
    func magpieChip(isSelected: Bool = false) -> some View {
        self
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? MagpieTheme.accentSoft : MagpieTheme.pill)
            .foregroundStyle(isSelected ? MagpieTheme.accent : MagpieTheme.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? MagpieTheme.accent.opacity(0.4) : MagpieTheme.borderSubtle, lineWidth: 1)
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
}

// MARK: - 炫酷呼吸光点指示器
struct MagpiePulseDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Circle()
                .stroke(color.opacity(0.5), lineWidth: 1)
                .frame(width: isPulsing ? 16 : 8, height: isPulsing ? 16 : 8)
                .opacity(isPulsing ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
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
