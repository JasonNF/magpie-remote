import SwiftUI

/// 尚未实现的功能页占位（保持导航结构完整，后续逐片替换）。
struct PlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                String(localized: "即将推出"),
                systemImage: systemImage,
                description: Text(String(localized: "\(title)页面正在开发中。"))
            )
            .navigationTitle(title)
        }
    }
}