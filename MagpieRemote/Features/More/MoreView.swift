import SwiftUI
import Foundation

/// 「更多」页：自定义的原生导航中心，承载官方 Web 手机端的更多页面。
/// 与系统自动 More 列表不同，这里用品牌化卡片直接呈现每个页面与其状态。
struct MoreView: View {
    @Environment(AppModel.self) private var app
    @Namespace private var zoomNamespace
    @State private var showingCustomizationSheet = false

    private var agentsCount: Int { app.state?.agents.count ?? 0 }
    private var servedCount: Int { app.state?.served ?? 0 }
    private var clientsCount: Int { app.state?.clients?.count ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    serverCard

                    VStack(alignment: .leading, spacing: 12) {
                        MagpieSectionLabel(
                            title: String(localized: "全部功能"),
                            detail: "\(MorePage.allCases.count)"
                        )
                        bubbleGrid(MorePage.allCases)
                    }

                    footer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .padding(.bottom, 96)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "更多"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomizationSheet = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel(String(localized: "自定义底栏"))
                }
            }
            .sheet(isPresented: $showingCustomizationSheet) {
                TabBarCustomizationSheet()
            }
            .navigationDestination(for: MorePage.self) { page in
                page.destination
                    .environment(\.magpieEmbeddedNavigation, true)
                    .navigationTransition(.zoom(sourceID: page, in: zoomNamespace))
            }
            .refreshable { await app.refresh() }
        }
    }

    // MARK: - 服务器卡片
    private var serverCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
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

    // MARK: - 统一圆形功能气泡
    private func bubbleGrid(_ pages: [MorePage]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 18
        ) {
            ForEach(pages) { page in
                NavigationLink(value: page) {
                    bubble(page)
                }
                .matchedTransitionSource(id: page, in: zoomNamespace)
                .buttonStyle(MagpiePressableStyle())
            }
        }
    }

    private func bubble(_ page: MorePage) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(page.colors[0].opacity(0.16))
                    .frame(width: 60, height: 60)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.45),
                                page.colors[0].opacity(0.30),
                                .white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: page.tabIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(page.colors[0])
            }
            .shadow(color: page.colors[0].opacity(0.22), radius: 7, x: 0, y: 3)

            Text(page.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(MagpieTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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

    var tabIcon: String {
        AppPage(rawValue: rawValue)?.icon ?? icon
    }

    var icon: String {
        switch self {
        case .routing: return "arrow.triangle.branch"
        case .groups: return "square.3.layers.3d"
        case .gateway: return "server.rack"
        case .usage: return "chart.bar.xaxis"
        case .masking: return "shield.lefthalf.filled"
        case .plugins: return "puzzlepiece.extension"
        case .settings: return "gearshape"
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

    @MainActor
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
