import SwiftUI

/// 与官方 Web UI（phonetabs.js / 侧边栏）一致的页面集合与顺序。
///
/// iPhone（compact）：底部 5 个 Tab —— Agents、Sessions、Library、Providers、
/// More。More 是自定义的原生页面，承载其余页面（Routing、Groups、Gateway、
/// Usage、Masking、Plugins、Settings）。
/// iPad / 大屏（regular）：`.sidebarAdaptable` 展开为分组侧边栏。
struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var compactSelection: AppPage = .agents
    @State private var regularSelection: AppPage = .agents

    var body: some View {
        if horizontalSizeClass == .compact {
            compactTabs
        } else {
            regularTabs
        }
    }

    // MARK: - iPhone
    private var compactTabs: some View {
        TabView(selection: $compactSelection) {
            Tab(value: AppPage.agents) {
                AgentsView()
            } label: {
                Label("Agents", systemImage: "terminal")
            }

            Tab(value: AppPage.sessions) {
                SessionsView()
            } label: {
                Label("Sessions", systemImage: "bubble.left.and.bubble.right")
            }

            Tab(value: AppPage.library) {
                LibraryView()
            } label: {
                Label("Library", systemImage: "books.vertical")
            }

            Tab(value: AppPage.providers) {
                ProvidersView()
            } label: {
                Label("Providers", systemImage: "key.radiowaves.forward")
            }

            Tab(value: AppPage.more) {
                MoreView()
            } label: {
                Label("更多", systemImage: "ellipsis.circle.fill")
            }
        }
        .tint(MagpieTheme.accent)
        .toolbarBackground(.visible, for: .tabBar)
    }

    // MARK: - iPad / 大屏
    private var regularTabs: some View {
        TabView(selection: $regularSelection) {
            TabSection("Work") {
                Tab(value: AppPage.agents) {
                    AgentsView()
                } label: {
                    Label("Agents", systemImage: "terminal")
                }

                Tab(value: AppPage.sessions) {
                    SessionsView()
                } label: {
                    Label("Sessions", systemImage: "bubble.left.and.bubble.right")
                }

                Tab(value: AppPage.library) {
                    LibraryView()
                } label: {
                    Label("Library", systemImage: "books.vertical")
                }
            }

            TabSection("Models") {
                Tab(value: AppPage.providers) {
                    ProvidersView()
                } label: {
                    Label("Providers", systemImage: "key.radiowaves.forward")
                }

                Tab(value: AppPage.routing) {
                    RoutingView()
                } label: {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }

                Tab(value: AppPage.groups) {
                    GroupsView()
                } label: {
                    Label("Routing groups", systemImage: "square.3.layers.3d")
                }

                Tab(value: AppPage.gateway) {
                    GatewayView()
                } label: {
                    Label("Gateway", systemImage: "server.rack")
                }
            }

            TabSection("Insights") {
                Tab(value: AppPage.usage) {
                    UsageView()
                } label: {
                    Label("Usage", systemImage: "chart.bar.xaxis")
                }

                Tab(value: AppPage.masking) {
                    MaskingView()
                } label: {
                    Label("Masking", systemImage: "shield.lefthalf.filled")
                }
            }

            TabSection("Extend") {
                Tab(value: AppPage.plugins) {
                    PluginsView()
                } label: {
                    Label("Plugins", systemImage: "puzzlepiece.extension")
                }
            }

            Tab(value: AppPage.settings) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(MagpieTheme.accent)
    }
}

/// 官方页面的稳定标识；顺序与 Web UI 的侧边栏一致。
enum AppPage: String, Hashable, CaseIterable {
    case agents
    case sessions
    case library
    case providers
    case routing
    case groups
    case gateway
    case usage
    case masking
    case plugins
    case settings
    case more
}
