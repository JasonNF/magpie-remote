import SwiftUI

// MARK: - iOS 26 Liquid Glass 设计系统
// 使用系统原生 Glass API（iOS 26.0+），而不是材质仿制。
// 低于 iOS 26 时回退到 ultraThinMaterial，保证观感连续。

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
struct MagpieGlassGroup<Content: View>: View {
    var spacing: CGFloat?
    var content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
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

    /// 原生玻璃按钮外观：按下时系统玻璃会做亮度/形变反馈。
    func magpieLiquidButton(tint: Color? = nil, cornerRadius: CGFloat = 999) -> some View {
        modifier(MagpieLiquidSurfaceModifier(cornerRadius: cornerRadius, tint: tint, interactive: true))
    }
}

private struct MagpieLiquidSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool

    func body(content: Content) -> some View {
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

/// 内容插入/移除的标准过渡（原点缩放 + 淡入，避免位移动画偏移）。
extension AnyTransition {
    static var magpieContent: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .center)),
            removal: .opacity
        )
    }
}
