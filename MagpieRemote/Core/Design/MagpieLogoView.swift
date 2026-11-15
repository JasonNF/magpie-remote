import SwiftUI

/// 官方 Magpie 喜鹊折纸品牌 Logo。
/// 使用官方原生矢量并在暗黑/浅色模式下自适应对比度。
struct MagpieLogoView: View {
    var size: CGFloat = 22
    var showText: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Image("magpie-logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(MagpieTheme.textPrimary)

            if showText {
                Text("magpie")
                    .font(.system(size: size * 0.9, weight: .bold, design: .rounded))
                    .foregroundStyle(MagpieTheme.textPrimary)
            }
        }
    }
}
