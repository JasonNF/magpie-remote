import SwiftUI

/// 全 App 统一的设计常量：间距、圆角、字号、动画。
/// 遵循 8 点网格与 Apple HIG；颜色一律走 Asset Catalog 命名色或系统语义色。
enum DS {
    /// 8 点网格间距。
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    /// 圆角（连续圆角为系统默认）。
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
    }

    /// 标准动画时长。
    enum Animation {
        static let quick: Double = 0.15
        static let standard: Double = 0.25
        static let slow: Double = 0.4
    }

    /// 最小可点击区域（Apple HIG）。
    static let minTapTarget: CGFloat = 44
}