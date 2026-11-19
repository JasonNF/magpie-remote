import SwiftUI
import SwiftData

/// 连接管理首页：服务器列表、添加、切换、删除。
/// 采用官方 magpie 折纸喜鹊品牌视觉与卡片层级。
struct ConnectionListView: View {
    @Query(sort: \Connection.sortOrder) private var connections: [Connection]
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @State private var showAdd = false
    @State private var editing: Connection?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 官方品牌 Header
                    brandHeader

                    // MARK: - 错误提示条
                    if app.phase == .error, let message = app.errorMessage {
                        Button {
                            if let target = connections.first(where: { $0.id == app.activeID }) ?? connections.first {
                                editing = target
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(MagpieTheme.red)
                                    .font(.headline)
                                Text(message)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.red)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(String(localized: "配置"))
                                        .font(.caption.weight(.semibold))
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                }
                                .foregroundStyle(MagpieTheme.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MagpieTheme.red.opacity(0.12), in: Capsule())
                            }
                            .magpieCard(padding: 14, cornerRadius: 18)
                        }
                        .buttonStyle(MagpieInteractiveCardButtonStyle())
                    }

                    // MARK: - 连接列表
                    if connections.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(String(localized: "MAGPIE WEB 服务器"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MagpieTheme.textMuted)
                                Spacer()
                                Text(String(localized: "\(connections.count) 个连接"))
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }
                            .padding(.horizontal, 4)

                            LazyVStack(spacing: 10) {
                                ForEach(connections) { connection in
                                    connectionCard(connection)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .magpiePageBackground()
            .navigationTitle("Magpie Remote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .task {
                if app.phase == .idle, !app.isConnected {
                    let target = connections.first(where: { $0.id == app.lastActiveID }) ?? (connections.count == 1 ? connections.first : nil)
                    if let target {
                        await app.activate(id: target.id, name: target.name, urlString: target.urlString)
                    }
                }
            }
            .sheet(isPresented: $showAdd) { ConnectionEditView() }
            .sheet(item: $editing) { connection in ConnectionEditView(editing: connection) }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.clear)
                    .frame(width: 76, height: 76)
                    .magpieLiquidSurface(cornerRadius: 38)
                    .shadow(color: MagpieTheme.accent.opacity(0.14), radius: 14, y: 6)
                MagpieLogoView(size: 40, showText: false)
            }

            Text(String(localized: "连接至您的 magpie 实例，在线调度 Agent 与模型"))
                .font(.subheadline)
                .foregroundStyle(MagpieTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(MagpieTheme.pill)
                    .frame(width: 64, height: 64)
                Image(systemName: "server.rack")
                    .font(.title)
                    .foregroundStyle(MagpieTheme.textMuted)
            }

            Text(String(localized: "尚未添加服务器"))
                .font(.headline)
                .foregroundStyle(MagpieTheme.textPrimary)

            Text(String(localized: "添加一个开启了 magpie web 的实例地址与 Web Key，即可随时在手机上管理模型与路由。"))
                .font(.subheadline)
                .foregroundStyle(MagpieTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                showAdd = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text(String(localized: "添加第一个连接"))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(MagpieTheme.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .magpieCard(padding: 24)
    }

    @ViewBuilder
    private func connectionCard(_ connection: Connection) -> some View {
        let hasKey = KeychainStore.read(for: connection.id.uuidString)?.isEmpty == false

        Button {
            MagpieHaptics.light()
            if !hasKey {
                editing = connection
            } else {
                Task {
                    await app.activate(id: connection.id, name: connection.name, urlString: connection.urlString)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(app.activeID == connection.id && app.isConnected ? MagpieTheme.greenSoft : MagpieTheme.pill)
                        .frame(width: 44, height: 44)
                    Image(systemName: "server.rack")
                        .font(.title3)
                        .foregroundStyle(app.activeID == connection.id && app.isConnected ? MagpieTheme.green : MagpieTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(connection.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MagpieTheme.textPrimary)

                        if app.activeID == connection.id && app.isConnected {
                            HStack(spacing: 4) {
                                MagpiePulseDot(color: MagpieTheme.green)
                                Text(String(localized: "已连接"))
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MagpieTheme.greenSoft)
                            .foregroundStyle(MagpieTheme.green)
                            .clipShape(Capsule())
                        } else if !hasKey {
                            Text(String(localized: "点此输入 Key"))
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MagpieTheme.amberSoft)
                                .foregroundStyle(MagpieTheme.amber)
                                .clipShape(Capsule())
                        }
                    }

                    Text(connection.urlString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                if app.activeID == connection.id && app.phase == .loading {
                    ProgressView()
                        .controlSize(.small)
                } else if !hasKey {
                    Image(systemName: "key.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MagpieTheme.amber)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .magpieLiquidCard(padding: 14, cornerRadius: 20)
        }
        .buttonStyle(MagpieInteractiveCardButtonStyle())
        .contextMenu {
            Button { editing = connection } label: {
                Label(String(localized: "编辑连接"), systemImage: "pencil")
            }
            Button(role: .destructive) { delete(connection) } label: {
                Label(String(localized: "删除连接"), systemImage: "trash")
            }
        }
    }

    private func delete(_ connection: Connection) {
        if app.activeID == connection.id { app.disconnect() }
        KeychainStore.delete(for: connection.id.uuidString)
        context.delete(connection)
        try? context.save()
    }
}
