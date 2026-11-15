import SwiftUI
import Foundation

/// 「更多」页：自定义的原生导航中心，承载官方 Web 手机端的更多页面。
/// 与系统自动 More 列表不同，这里用品牌化卡片直接呈现每个页面与其状态。
struct MoreView: View {
    @Environment(AppModel.self) private var app

    private var agentsCount: Int { app.state?.agents.count ?? 0 }
    private var servedCount: Int { app.state?.served ?? 0 }
    private var clientsCount: Int { app.state?.clients?.count ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    serverCard
                    section(title: String(localized: "模型与路由")) {
                        tileGrid([.routing, .groups])
                    }
                    section(title: String(localized: "网关与用量")) {
                        tileGrid([.gateway, .usage])
                    }
                    section(title: String(localized: "安全与扩展")) {
                        tileGrid([.masking, .plugins])
                    }
                    settingsCard
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "更多"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: MorePage.self) { page in
                page.destination
                    .environment(\.magpieEmbeddedNavigation, true)
            }
            .refreshable { await app.refresh() }
        }
    }

    // MARK: - 服务器卡片
    private var serverCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.18), lineWidth: 0.8)
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: MagpieTheme.accent.opacity(0.2), radius: 10, y: 4)
                    Image(systemName: "bird.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MagpieTheme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(app.activeName.isEmpty ? String(localized: "未连接") : app.activeName)
                            .font(.headline)
                            .foregroundStyle(MagpieTheme.textPrimary)

                        MagpieStatusChip(
                            text: app.isConnected ? String(localized: "在线") : String(localized: "离线"),
                            color: app.isConnected ? MagpieTheme.green : MagpieTheme.amber
                        )
                    }

                    if let url = app.activeURL {
                        Text(url.absoluteString)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(MagpieTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        Task { await app.refresh() }
                    } label: {
                        Label(String(localized: "刷新状态"), systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        app.disconnect()
                    } label: {
                        Label(String(localized: "断开连接"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }

            Divider().background(MagpieTheme.borderSubtle)

            HStack(spacing: 0) {
                stat(value: "\(agentsCount)", title: String(localized: "Agents"), tint: MagpieTheme.accent)
                statDivider
                stat(value: "\(servedCount)", title: String(localized: "可用模型"), tint: MagpieTheme.green)
                statDivider
                stat(value: "\(clientsCount)", title: String(localized: "客户端"), tint: MagpieTheme.cyan)
            }
        }
        .magpieCard()
    }

    private func stat(value: String, title: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            MagpieGradientNumber(text: value, tint: tint, size: 21)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(MagpieTheme.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(MagpieTheme.borderSubtle)
            .frame(width: 1, height: 28)
    }

    // MARK: - 分区
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MagpieSectionLabel(title: title)
            content()
        }
    }

    private func tileGrid(_ pages: [MorePage]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(pages) { page in
                NavigationLink(value: page) {
                    tile(page)
                }
                .buttonStyle(MagpiePressableStyle())
            }
        }
    }

    private func tile(_ page: MorePage) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: page.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: page.colors[0].opacity(0.28), radius: 8, x: 0, y: 4)
                    Image(systemName: page.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MagpieTheme.textMuted.opacity(0.55))
            }

            Text(page.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MagpieTheme.textPrimary)

            Text(page.subtitle)
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .magpieCard(padding: 13)
    }

    // MARK: - 设置入口
    private var settingsCard: some View {
        NavigationLink(value: MorePage.settings) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "64748b"), Color(hex: "334155")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Settings"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(String(localized: "外观、用量、网络、模型与隐私"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Spacer()

                Text(app.activeName.isEmpty ? "—" : app.activeName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
            }
            .magpieCard(padding: 13)
        }
        .buttonStyle(MagpiePressableStyle())
    }

    // MARK: - 页脚
    private var footer: some View {
        VStack(spacing: 4) {
            MagpieLogoView(size: 18, showText: true)
            Text("Magpie Remote \(appVersion) · 原生 SwiftUI")
                .font(.system(size: 9.5))
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }
}

// MARK: - 更多页面
enum MorePage: String, Hashable, CaseIterable, Identifiable {
    case routing
    case groups
    case gateway
    case usage
    case masking
    case plugins
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routing: return String(localized: "Routing")
        case .groups: return String(localized: "路由组")
        case .gateway: return String(localized: "Gateway")
        case .usage: return String(localized: "Usage")
        case .masking: return String(localized: "Masking")
        case .plugins: return String(localized: "Plugins")
        case .settings: return String(localized: "Settings")
        }
    }

    var subtitle: String {
        switch self {
        case .routing: return String(localized: "实时决策链与故障转移")
        case .groups: return String(localized: "成员、策略与就绪状态")
        case .gateway: return String(localized: "调用密钥、权限与预算")
        case .usage: return String(localized: "用量、配额与费用")
        case .masking: return String(localized: "脱敏规则与请求记录")
        case .plugins: return String(localized: "安装、更新与扩展")
        case .settings: return String(localized: "外观、网络与隐私")
        }
    }

    var icon: String {
        switch self {
        case .routing: return "arrow.triangle.branch"
        case .groups: return "square.3.layers.3d"
        case .gateway: return "server.rack"
        case .usage: return "chart.bar.xaxis"
        case .masking: return "shield.lefthalf.filled"
        case .plugins: return "puzzlepiece.extension.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .routing: return [Color(hex: "8b5cf6"), Color(hex: "6d28d9")]
        case .groups: return [Color(hex: "0ea5e9"), Color(hex: "2563eb")]
        case .gateway: return [Color(hex: "f59e0b"), Color(hex: "d97706")]
        case .usage: return [Color(hex: "10b981"), Color(hex: "059669")]
        case .masking: return [Color(hex: "14b8a6"), Color(hex: "0d9488")]
        case .plugins: return [Color(hex: "ec4899"), Color(hex: "db2777")]
        case .settings: return [Color(hex: "64748b"), Color(hex: "334155")]
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .routing:
            RoutingView()
        case .groups:
            GroupsView()
        case .gateway:
            GatewayView()
        case .usage:
            UsageView()
        case .masking:
            MaskingView()
        case .plugins:
            PluginsView()
        case .settings:
            SettingsView()
        }
    }
}
