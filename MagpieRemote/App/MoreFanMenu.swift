import SwiftUI

/// The fan originates at the actual More button, including when the bottom bar changes width.
struct MoreFanAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct MoreFanMenu: View {
    let pages: [AppPage]
    let origin: CGPoint
    let size: CGSize
    let progress: CGFloat
    let onSelect: (AppPage) -> Void
    let onCustomize: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .subheadline) private var labelHeight: CGFloat = 30

    private static let regularIconSize: CGFloat = 46
    private static let compactIconSize: CGFloat = 40
    private static let triggerGap: CGFloat = 34
    private static let topClearance: CGFloat = 28
    private static let edgeMargin: CGFloat = 24

    var body: some View {
        let count = pages.count + 1
        let bottom = origin.y - Self.triggerGap
        let availableHeight = max(0, bottom - Self.topClearance)
        let direction: CGFloat = layoutDirection == .leftToRight ? 1 : -1
        let trailingSpace = direction > 0 ? size.width - origin.x : origin.x

        let singleRowHeight = max(Self.regularIconSize, labelHeight)
        let singleMinPitch = singleRowHeight + 5
        let fitsSingleColumn = singleMinPitch * CGFloat(count) <= availableHeight + 0.5

        let compactRowHeight = max(Self.compactIconSize, labelHeight)
        let compactMinPitch = compactRowHeight + 6
        let rightColumnCount = (count + 1) / 2
        let useTwoColumns = !fitsSingleColumn
            && size.width >= 480
            && compactMinPitch * CGFloat(rightColumnCount) <= availableHeight + 0.5

        let iconSize = useTwoColumns ? Self.compactIconSize : Self.regularIconSize
        let rowHeight = useTwoColumns ? compactRowHeight : singleRowHeight

        if useTwoColumns {
            let columnStride = min(195, max(156, size.width * 0.27))
            let pitch = max(compactMinPitch, min(rowHeight + 14, availableHeight / CGFloat(rightColumnCount)))
            let contentHeight = pitch * CGFloat(rightColumnCount)
            let reach = max(0, min(size.width * 0.10, trailingSpace - iconSize / 2 - Self.edgeMargin))
            let rowWidth = min(columnStride - 12, 180)
            let localOrigin = CGPoint(x: origin.x, y: contentHeight + Self.triggerGap)

            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let rank = count - index - 1
                    let isSecondColumn = rank >= rightColumnCount
                    let columnRank = isSecondColumn ? rank - rightColumnCount : rank
                    let columnAnchorX = isSecondColumn ? origin.x - direction * columnStride : origin.x
                    let targetY = pitch * (CGFloat(rightColumnCount - columnRank) - 0.5)
                    menuRow(at: index, iconSize: iconSize)
                        .modifier(FanPlacement(
                            rank: rank, count: count,
                            rowWidth: rowWidth, rowHeight: rowHeight, iconSize: iconSize,
                            launchOrigin: localOrigin,
                            columnOriginX: columnAnchorX,
                            targetY: targetY,
                            peakRise: localOrigin.y - pitch / 2,
                            reach: reach, direction: direction,
                            progress: progress,
                            moves: !reduceMotion
                        ))
                }
            }
            .frame(width: size.width, height: contentHeight)
            .position(x: size.width / 2, y: bottom - contentHeight / 2)
        } else {
            let pitch = max(singleMinPitch, min(rowHeight + 16, availableHeight / CGFloat(count)))
            let contentHeight = pitch * CGFloat(count)
            let height = min(availableHeight, contentHeight)
            let scrolls = contentHeight > availableHeight + 0.5
            let reach = max(0, min(size.width * 0.14, trailingSpace - iconSize / 2 - Self.edgeMargin))
            let rowWidth = min(244, max(iconSize, size.width - trailingSpace + iconSize / 2 - 14))
            let scrollWidth = min(size.width, rowWidth + reach + Self.edgeMargin)
            let containerWidth = scrolls ? scrollWidth : size.width
            let localOriginX = scrolls
                ? (direction > 0 ? containerWidth - reach - iconSize / 2 - Self.edgeMargin : reach + iconSize / 2 + Self.edgeMargin)
                : origin.x
            let localOrigin = CGPoint(x: localOriginX, y: contentHeight + Self.triggerGap)

            let rows = ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let rank = count - index - 1
                    let targetY = pitch * (CGFloat(count - rank) - 0.5)
                    menuRow(at: index, iconSize: iconSize)
                        .modifier(FanPlacement(
                            rank: rank, count: count,
                            rowWidth: rowWidth, rowHeight: rowHeight, iconSize: iconSize,
                            launchOrigin: localOrigin,
                            columnOriginX: localOriginX,
                            targetY: targetY,
                            peakRise: localOrigin.y - pitch / 2,
                            reach: reach, direction: direction,
                            progress: progress,
                            moves: !reduceMotion && !scrolls
                        ))
                }
            }
            .frame(width: containerWidth, height: contentHeight)

            Group {
                if scrolls {
                    ScrollView { rows }
                        .defaultScrollAnchor(.bottom)
                        .scrollIndicators(.visible)
                        .frame(width: containerWidth, height: height)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.06),
                                    .init(color: .black, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    rows
                }
            }
            .position(
                x: scrolls
                    ? (direction > 0 ? size.width - containerWidth / 2 : containerWidth / 2)
                    : size.width / 2,
                y: bottom - height / 2
            )
        }
    }

    private func menuRow(at index: Int, iconSize: CGFloat) -> some View {
        let page = index < pages.count ? pages[index] : nil
        return row(
            page?.shortTitle ?? String(localized: "自定义底栏"),
            icon: page?.icon ?? "slider.horizontal.3",
            tint: page?.primaryColor ?? MagpieTheme.accent,
            iconSize: iconSize
        ) {
            if let page {
                onSelect(page)
            } else {
                onCustomize()
            }
        }
    }

    private func row(_ title: String, icon: String, tint: Color, iconSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            MagpieHaptics.light()
            action()
        } label: {
            HStack(spacing: 9) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background {
                        if reduceTransparency {
                            Capsule().fill(MagpieTheme.card)
                        } else {
                            Capsule().fill(.regularMaterial)
                        }
                    }
                    .overlay { Capsule().strokeBorder(MagpieTheme.borderSubtle, lineWidth: 0.6) }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 5, y: 2)

                Image(systemName: icon)
                    .font(.system(size: iconSize >= 44 ? 20 : 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: iconSize, height: iconSize)
                    .background {
                        Circle()
                            .fill(tint.opacity(0.14))
                            .background(MagpieTheme.card, in: Circle())
                    }
                    .overlay { Circle().strokeBorder(tint.opacity(0.35), lineWidth: 0.7) }
                    .shadow(color: tint.opacity(0.24), radius: 7, y: 3)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(FanPressStyle())
        .accessibilityLabel(title)
        .accessibilityAction(.escape) { onDismiss() }
    }
}

private struct FanPlacement: ViewModifier, @MainActor Animatable {
    let rank: Int
    let count: Int
    let rowWidth: CGFloat
    let rowHeight: CGFloat
    let iconSize: CGFloat
    let launchOrigin: CGPoint
    let columnOriginX: CGFloat
    let targetY: CGFloat
    let peakRise: CGFloat
    let reach: CGFloat
    let direction: CGFloat
    var progress: CGFloat
    let moves: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        if progress > 0.001 {
            // One shared spring drives both directions. Items farther from the trigger join later.
            let denom = max(1, count - 1)
            let lag = moves ? 0.46 * CGFloat(rank) / CGFloat(denom) : 0
            let phase = min(1, max(0, (progress - lag) / (1 - lag)))
            let t = moves ? phase : 1
            let rise = (launchOrigin.y - targetY) * t
            let distance = peakRise > 0 ? rise / peakRise : 0
            let arcShift = reach * distance * distance
            let iconInset = (rowWidth - iconSize) / 2
            let targetIconX = columnOriginX + direction * arcShift
            let currentIconX = launchOrigin.x + (targetIconX - launchOrigin.x) * t
            let pivot = UnitPoint(x: 0.5 + direction * iconInset / rowWidth, y: 0.5)
            let tilt = direction * min(14, Double(reach * distance / max(1, peakRise)) * 90)

            content
                .frame(width: rowWidth, height: rowHeight, alignment: .trailing)
                .scaleEffect(moves ? 0.35 + 0.65 * phase : 1, anchor: pivot)
                .rotationEffect(.degrees(tilt), anchor: pivot)
                .position(x: currentIconX - direction * iconInset, y: launchOrigin.y - rise)
                .opacity(Double(moves ? min(1, phase * 2.4) : phase))
                .allowsHitTesting(!moves || phase >= 0.8)
        }
    }
}

private struct FanPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
