import SwiftUI

// MARK: - iOS 26/27 Liquid Glass 设计系统
// 使用系统原生 Glass API（iOS 26.0+），保证极致性能与物理级折射反射。
// 低于 iOS 26 时回退到 ultraThinMaterial，保证系统向下兼容。

/// 统一的 Liquid Glass 表面：原生玻璃材质 + 可选品牌着色 + 交互高光。
struct MagpieGlassSurface<Content: View>: View {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool
    var content: Content

    init(
        cornerRadius: CGFloat = 20,
        tint: Color? = nil,
        interactive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.interactive = interactive
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var value = Glass.regular
        if let tint {
            value = value.tint(tint)
        }
        if interactive {
            value = value.interactive()
        }
        return value
    }
}

/// 一组相邻玻璃元素共享同一容器：系统会把它们融合成连续液面。
/// 专用于工具栏、底部栏、胶囊按钮组这类连续小控件；列表卡片保持各自边界。
struct MagpieGlassGroup<Content: View>: View {
    var spacing: CGFloat?
    var merges: Bool
    var content: Content

    init(spacing: CGFloat? = nil, merges: Bool = false, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.merges = merges
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *), merges {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    /// 原生 Liquid Glass 卡片（iOS 26+），带玻璃高光与可选品牌着色。
    func magpieLiquidCard(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        tint: Color? = nil
    ) -> some View {
        self
            .padding(padding)
            .magpieLiquidSurface(cornerRadius: cornerRadius, tint: tint)
    }

    /// 只加玻璃表面，不改内边距。
    func magpieLiquidSurface(
        cornerRadius: CGFloat = 20,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(MagpieLiquidSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    /// 原生玻璃胶囊按钮外观：按下时系统玻璃会做亮度/形变反馈。
    func magpieLiquidButton(tint: Color? = nil, cornerRadius: CGFloat = 999) -> some View {
        modifier(MagpieLiquidSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: true))
    }

    /// 原生玻璃胶囊外观（用于标签、小按钮、气泡芯片）。
    func magpieLiquidCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(MagpieLiquidCapsuleModifier(tint: tint, interactive: interactive))
    }
}

private struct MagpieLiquidSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), interactive {
            // 交互式浮动表面（如浮动栏、凸起胶囊按钮）：采用 Apple 原生 Liquid Glass
            content
                .background(shape.fill(MagpieTheme.card.opacity(colorScheme == .dark ? 0.76 : 0.85)))
                .glassEffect(glass, in: shape)
                .overlay(
                    shape.stroke(MagpieTheme.borderSubtle, lineWidth: 0.6)
                )
        } else {
            // 列表卡片与内容面板：采用纯净 Apple 系统分组背景，零掉帧 120Hz 极速渲染
            content
                .background(shape.fill(MagpieTheme.card))
                .overlay(
                    shape.stroke(MagpieTheme.borderSubtle, lineWidth: 0.6)
                )
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var value = Glass.regular
        if let tint {
            value = value.tint(tint)
        }
        if interactive {
            value = value.interactive()
        }
        return value
    }
}

private struct MagpieLiquidCapsuleModifier: ViewModifier {
    var tint: Color?
    var interactive: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), interactive {
            content
                .background(Capsule().fill(MagpieTheme.card.opacity(colorScheme == .dark ? 0.72 : 0.85)))
                .glassEffect(glass, in: .capsule)
                .overlay(
                    Capsule().stroke(MagpieTheme.borderSubtle, lineWidth: 0.6)
                )
        } else {
            content
                .background(Capsule().fill(MagpieTheme.pill))
                .overlay(
                    Capsule().stroke(MagpieTheme.borderSubtle, lineWidth: 0.6)
                )
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var value = Glass.regular
        if let tint { value = value.tint(tint) }
        if interactive { value = value.interactive() }
        return value
    }
}

/// 交互式卡片按钮样式：iOS 26/27 原生回弹缩放与微触感。
struct MagpieInteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// 内容插入/移除的标准过渡（原点缩放 + 淡入，避免位移动画偏移）。
extension AnyTransition {
    static var magpieContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .center)),
            removal: .opacity
        )
    }
}
