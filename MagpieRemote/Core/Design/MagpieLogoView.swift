import SwiftUI

/// 官方 Magpie 喜鹊折纸品牌 Logo。
/// 1:1 复刻 Web 官方 原生动画（.logo.wag / app.css）：
/// 喜鹊由同一张 SVG 分为身体、尾巴、翅膀三部分，
/// 尾巴以 (14, 22) 摆动，翅膀以 (30, 19.8) 扑动，整鸟以 (26, 38) 呼吸微俯仰。
struct MagpieLogoView: View {
    var size: CGFloat = 22
    var showText: Bool = true
    var isAnimated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HStack(spacing: 8) {
            birdGraphic
                .frame(width: size, height: size)

            if showText {
                Text("magpie")
                    .font(.system(size: size * 0.9, weight: .bold, design: .rounded))
                    .foregroundStyle(MagpieTheme.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var birdGraphic: some View {
        if isAnimated && !reduceMotion {
            // 交给 Core Animation 在渲染进程里循环播放：动作与原先逐帧计算的版本一致，
            // 但 App 主线程不再每秒 30 次重算三层蒙版视图（首页常驻时这是主要的发热来源）。
            MagpieBirdWagView(isActive: scenePhase == .active)
                .accessibilityHidden(true)
        } else {
            birdImage
        }
    }

    private var birdImage: some View {
        Image("magpie-logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(MagpieTheme.textPrimary)
    }
}

// MARK: - 官方 SVG 裁切路径 (44x44 viewBox 严格对应 Web index.html defs)
struct MagpieBirdClipShape: Shape {
    enum Part {
        case body
        case tail
        case wing
    }

    let part: Part

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 44.0
        let sy = rect.height / 44.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        switch part {
        case .body:
            path.move(to: pt(16, 0))
            path.addLine(to: pt(44, 0))
            path.addLine(to: pt(44, 44))
            path.addLine(to: pt(0, 44))
            path.addLine(to: pt(0, 26.4))
            path.addLine(to: pt(10.6, 26.4))
            path.addLine(to: pt(13, 24.2))
            path.addLine(to: pt(16, 19))
            path.closeSubpath()

            path.move(to: pt(29.8, 18.3))
            path.addLine(to: pt(26, 19))
            path.addLine(to: pt(22, 21))
            path.addLine(to: pt(17, 23.5))
            path.addLine(to: pt(14.6, 24.7))
            path.addLine(to: pt(10.6, 26.4))
            path.addLine(to: pt(6, 29))
            path.addLine(to: pt(6, 32))
            path.addLine(to: pt(9, 31.5))
            path.addLine(to: pt(12.5, 32))
            path.addLine(to: pt(16.4, 31.8))
            path.addLine(to: pt(19, 31.4))
            path.addLine(to: pt(24, 28.8))
            path.addLine(to: pt(28.5, 24))
            path.addLine(to: pt(30.6, 21.4))
            path.closeSubpath()

        case .tail:
            path.move(to: pt(0, 0))
            path.addLine(to: pt(17, 0))
            path.addLine(to: pt(17.2, 19.6))
            path.addLine(to: pt(14, 25))
            path.addLine(to: pt(10.6, 26.4))
            path.addLine(to: pt(0, 26.4))
            path.closeSubpath()

        case .wing:
            path.move(to: pt(29.8, 18.3))
            path.addLine(to: pt(26, 19))
            path.addLine(to: pt(22, 21))
            path.addLine(to: pt(17, 23.5))
            path.addLine(to: pt(14.6, 24.7))
            path.addLine(to: pt(10.6, 26.4))
            path.addLine(to: pt(6, 29))
            path.addLine(to: pt(6, 32))
            path.addLine(to: pt(9, 31.5))
            path.addLine(to: pt(12.5, 32))
            path.addLine(to: pt(16.4, 31.8))
            path.addLine(to: pt(19, 31.4))
            path.addLine(to: pt(24, 28.8))
            path.addLine(to: pt(28.5, 24))
            path.addLine(to: pt(30.6, 21.4))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Core Animation 版摆动小鸟

/// 与 Web `.logo.wag` 相同的三段动作（尾巴摆动、翅膀扑动、整鸟微俯仰），
/// 用 CAKeyframeAnimation 无限循环，由系统渲染进程驱动，不占用 App 主线程。
struct MagpieBirdWagView: UIViewRepresentable {
    var isActive: Bool = true

    func makeUIView(context: Context) -> MagpieBirdWagUIView {
        MagpieBirdWagUIView()
    }

    func updateUIView(_ view: MagpieBirdWagUIView, context: Context) {
        view.setAnimating(isActive)
    }
}

final class MagpieBirdWagUIView: UIView {
    /// 一次完整摆动的时长，与原逐帧版本一致。
    static let cycle: CFTimeInterval = 0.9

    // (时间 0…1, 角度°)，与原 SwiftUI 版本的关键帧逐一对应
    static let tailKeyframes: [(Double, Double)] = [(0.0, 0.0), (0.18, 16.0), (0.36, -7.0), (0.54, 9.0), (0.72, -3.0), (0.86, 2.0), (1.0, 0.0)]
    static let wingKeyframes: [(Double, Double)] = [(0.0, 0.0), (0.12, 10.0), (0.26, -3.0), (0.40, 8.0), (0.56, -2.0), (0.72, 3.0), (1.0, 0.0)]
    static let bobKeyframes: [(Double, Double)] = [(0.0, 0.0), (0.18, -4.0), (0.40, 2.0), (0.62, -1.0), (1.0, 0.0)]

    private let bob = UIView()
    private let body = UIImageView()
    private let tail = UIImageView()
    private let wing = UIImageView()
    private var wantsAnimation = true
    private static let animationKey = "magpie.wag"

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        addSubview(bob)
        let image = UIImage(named: "magpie-logo")?.withRenderingMode(.alwaysTemplate)
        for part in [body, tail, wing] {
            part.image = image
            part.contentMode = .scaleAspectFit
            part.tintColor = .label
            bob.addSubview(part)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 与 `.scaledToFit()` 一致：在视图内居中放一个正方形画布（44×44 viewBox）
        let side = min(bounds.width, bounds.height)
        let canvas = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        place(bob, in: canvas, anchor: CGPoint(x: 26.0 / 44.0, y: 38.0 / 44.0))
        let local = CGRect(origin: .zero, size: canvas.size)
        place(body, in: local, anchor: CGPoint(x: 0.5, y: 0.5))
        place(tail, in: local, anchor: CGPoint(x: 14.0 / 44.0, y: 22.0 / 44.0))
        place(wing, in: local, anchor: CGPoint(x: 30.0 / 44.0, y: 19.8 / 44.0))
        mask(body, part: .body, size: canvas.size, evenOdd: true)
        mask(tail, part: .tail, size: canvas.size, evenOdd: false)
        mask(wing, part: .wing, size: canvas.size, evenOdd: false)
        installAnimationsIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installAnimationsIfNeeded()
    }

    func setAnimating(_ animating: Bool) {
        guard animating != wantsAnimation else { return }
        wantsAnimation = animating
        if animating {
            installAnimationsIfNeeded()
        } else {
            [bob, tail, wing].forEach { $0.layer.removeAnimation(forKey: Self.animationKey) }
        }
    }

    /// 不在窗口里（切到其他标签页、页面已关闭）时不挂动画；回来时重新挂上。
    private func installAnimationsIfNeeded() {
        guard wantsAnimation, window != nil, bounds.width > 0 else { return }
        add(Self.tailKeyframes, to: tail.layer)
        add(Self.wingKeyframes, to: wing.layer)
        add(Self.bobKeyframes, to: bob.layer)
    }

    private func add(_ keyframes: [(Double, Double)], to layer: CALayer) {
        guard layer.animation(forKey: Self.animationKey) == nil else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        animation.values = keyframes.map { $0.1 * .pi / 180 }
        animation.keyTimes = keyframes.map { NSNumber(value: $0.0) }
        // 原版每段用 smoothstep 缓动，对应 easeInEaseOut
        animation.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: max(keyframes.count - 1, 1)
        )
        animation.duration = Self.cycle
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: Self.animationKey)
    }

    private func place(_ view: UIView, in rect: CGRect, anchor: CGPoint) {
        view.layer.anchorPoint = anchor
        view.bounds = CGRect(origin: .zero, size: rect.size)
        view.center = CGPoint(x: rect.minX + anchor.x * rect.width, y: rect.minY + anchor.y * rect.height)
    }

    private func mask(_ view: UIView, part: MagpieBirdClipShape.Part, size: CGSize, evenOdd: Bool) {
        let shape = (view.layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        shape.frame = CGRect(origin: .zero, size: size)
        shape.path = MagpieBirdClipShape(part: part).path(in: CGRect(origin: .zero, size: size)).cgPath
        shape.fillRule = evenOdd ? .evenOdd : .nonZero
        view.layer.mask = shape
    }
}
