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
            TimelineView(AnimationTimelineSchedule(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let cycle = 0.9
                let progress = (now.truncatingRemainder(dividingBy: cycle)) / cycle

                let tailAngle = Self.interpolate(
                    t: progress,
                    keyframes: [(0.0, 0.0), (0.18, 16.0), (0.36, -7.0), (0.54, 9.0), (0.72, -3.0), (0.86, 2.0), (1.0, 0.0)]
                )
                let wingAngle = Self.interpolate(
                    t: progress,
                    keyframes: [(0.0, 0.0), (0.12, 10.0), (0.26, -3.0), (0.40, 8.0), (0.56, -2.0), (0.72, 3.0), (1.0, 0.0)]
                )
                let bobAngle = Self.interpolate(
                    t: progress,
                    keyframes: [(0.0, 0.0), (0.18, -4.0), (0.40, 2.0), (0.62, -1.0), (1.0, 0.0)]
                )

                ZStack {
                    // 身体部分 (bird-body clip)
                    birdImage
                        .mask(
                            MagpieBirdClipShape(part: .body)
                                .fill(.white, style: FillStyle(eoFill: true))
                        )

                    // 尾羽部分 (bird-tail clip, transform-origin: 14px 22px)
                    birdImage
                        .mask(
                            MagpieBirdClipShape(part: .tail)
                                .fill(.white)
                        )
                        .rotationEffect(.degrees(tailAngle), anchor: UnitPoint(x: 14.0 / 44.0, y: 22.0 / 44.0))

                    // 翅膀部分 (bird-wing clip, transform-origin: 30px 19.8px)
                    birdImage
                        .mask(
                            MagpieBirdClipShape(part: .wing)
                                .fill(.white)
                        )
                        .rotationEffect(.degrees(wingAngle), anchor: UnitPoint(x: 30.0 / 44.0, y: 19.8 / 44.0))
                }
                .rotationEffect(.degrees(bobAngle), anchor: UnitPoint(x: 26.0 / 44.0, y: 38.0 / 44.0))
            }
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

    private static func interpolate(t: Double, keyframes: [(Double, Double)]) -> Double {
        let clamped = min(max(t, 0.0), 1.0)
        for i in 0..<(keyframes.count - 1) {
            let (t0, a0) = keyframes[i]
            let (t1, a1) = keyframes[i + 1]
            if clamped >= t0 && clamped <= t1 {
                let seg = (clamped - t0) / (t1 - t0)
                // cubic-bezier(.3, 0, .3, 1) easeInOut 平滑插值
                let s = seg * seg * (3.0 - 2.0 * seg)
                return a0 + (a1 - a0) * s
            }
        }
        return keyframes.last?.1 ?? 0.0
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
