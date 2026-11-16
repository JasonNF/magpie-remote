import SwiftUI
import SwiftData

/// 根视图：未连接时管理连接，已连接时进入主界面。
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @State private var devConnectAttempted = false
    @State private var devPreview: String? = ProcessInfo.processInfo.environment["MAGPIE_DEV_PREVIEW"]

    var body: some View {
        Group {
            if app.isConnected {
                MainTabView()
                    .transition(.magpieContent)
            } else {
                ConnectionListView()
                    .transition(.magpieContent)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: app.isConnected)
        .task {
            await devConnectIfNeeded()
        }
        #if DEBUG
        .fullScreenCover(isPresented: Binding(
            get: { app.isConnected && devPreview != nil },
            set: { if !$0 { devPreview = nil } }
        )) {
            DevPreviewHost(kind: devPreview ?? "")
                .environment(app)
        }
        #endif
    }

    /// DEBUG 联调用：`SIMCTL_CHILD_MAGPIE_DEV_URL` / `SIMCTL_CHILD_MAGPIE_DEV_KEY`
    /// 启动时自动创建并激活一个开发连接，免去在模拟器里手输。
    private func devConnectIfNeeded() async {
        #if DEBUG
        guard !devConnectAttempted else { return }
        devConnectAttempted = true
        let env = ProcessInfo.processInfo.environment

        let descriptor = FetchDescriptor<Connection>()
        let connections = (try? context.fetch(descriptor)) ?? []

        // 模拟器调试兜底：若存在 mapm 测试连接但缺少 Key，注入单元测试中的公开测试 Key
        for conn in connections {
            if conn.urlString.contains("mapm.2020713.xyz") && (KeychainStore.read(for: conn.id.uuidString)?.isEmpty ?? true) {
                KeychainStore.save("79261a46b263781ddc6af6d168a8597543d8065fc5f71f14c2b942bef3f8afa0", for: conn.id.uuidString)
            }
        }

        if let target = connections.first(where: { (KeychainStore.read(for: $0.id.uuidString)?.isEmpty == false) }), !app.isConnected {
            await app.activate(id: target.id, name: target.name, urlString: target.urlString)
            return
        }

        guard let urlString = env["MAGPIE_DEV_URL"], !urlString.isEmpty,
              let key = env["MAGPIE_DEV_KEY"], !key.isEmpty else { return }
        // 联调模式总是以环境变量为准：覆盖旧连接里可能失效的 key。
        if app.activeID != nil, app.activeURL?.absoluteString == urlString, app.isConnected {
            return
        }

        let connection: Connection
        if let existing = connections.first(where: { $0.urlString == urlString }) {
            connection = existing
        } else {
            connection = Connection(name: "Dev", urlString: urlString, sortOrder: 0)
            context.insert(connection)
            try? context.save()
        }
        KeychainStore.save(key, for: connection.id.uuidString)
        await app.activate(
            id: connection.id,
            name: connection.name,
            urlString: connection.urlString
        )
        #endif
    }
}

#if DEBUG
/// 仅调试：`MAGPIE_DEV_PREVIEW=agent-models` / `provider-edit` 直接打开页面用于截图核对。
private struct DevPreviewHost: View {
    let kind: String
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var providersVM = ProvidersViewModel()
    @State private var libraryVM = LibraryViewModel()
    @State private var loaded = false

    private var agentID: String {
        ProcessInfo.processInfo.environment["MAGPIE_DEV_AGENT"] ?? "claude"
    }

    var body: some View {
        Group {
            switch kind {
            case "agent-models":
                NavigationStack {
                    AgentModelsView(agentID: agentID)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "关闭")) { dismiss() }
                            }
                        }
                }
            case "provider-edit":
                if loaded, let id = providersVM.providers.first?.id {
                    NavigationStack {
                        ProviderDetailView(providerID: id)
                            .environment(providersVM)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(String(localized: "关闭")) { dismiss() }
                                }
                            }
                    }
                } else {
                    ProgressView(String(localized: "读取 Providers…"))
                        .task {
                            if let client = app.client, !loaded {
                                await providersVM.load(client: client)
                                loaded = true
                            }
                        }
                }
            case "plugin-signin":
                if loaded, let plugin = providersVM.plugins.first {
                    PluginSignInSheet(plugin: plugin)
                        .environment(providersVM)
                } else {
                    ProgressView(String(localized: "读取插件订阅…"))
                        .task {
                            if let client = app.client, !loaded {
                                await providersVM.load(client: client)
                                loaded = true
                            }
                        }
                }
            case "market":
                if loaded {
                    LibraryMarketSheet(initialKind: "skills")
                        .environment(libraryVM)
                } else {
                    ProgressView(String(localized: "读取 Library…"))
                        .task {
                            if let client = app.client, !loaded {
                                await libraryVM.load(client: client)
                                loaded = true
                            }
                        }
                }
            default:
                Color.clear
            }
        }
    }
}
#endif
