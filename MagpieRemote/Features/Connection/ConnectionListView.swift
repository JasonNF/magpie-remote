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
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(MagpieTheme.red)
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(MagpieTheme.red)
                            Spacer()
                        }
                        .magpieCard()
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
            .sheet(isPresented: $showAdd) { ConnectionEditView() }
            .sheet(item: $editing) { connection in ConnectionEditView(editing: connection) }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.8))
                    .shadow(color: MagpieTheme.accent.opacity(0.12), radius: 12, y: 6)
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

    private func connectionCard(_ connection: Connection) -> some View {
        Button {
            Task {
                await app.activate(id: connection.id, name: connection.name, urlString: connection.urlString)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                            Text(String(localized: "已连接"))
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MagpieTheme.greenSoft)
                                .foregroundStyle(MagpieTheme.green)
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
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }
            .magpieCard(padding: 14)
        }
        .buttonStyle(.plain)
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
