import SwiftUI
import UIKit

/// Agent 详情：字段编辑器（model / effort / opus / sonnet …），支持切换模型、接入控制与行操作。
struct AgentDetailView: View {
    let agentID: String
    @Environment(AppModel.self) private var app
    @State private var actionVM = AgentsViewModel()
    @State private var actionMessage: String?

    private var agent: AgentDTO? {
        app.state?.agents.first { $0.id == agentID }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let agent {
                    // MARK: - Agent 头部概要卡片
                    headerCard(agent)

                    NavigationLink {
                        AgentModelsView(agentID: agentID)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(MagpieTheme.purple.opacity(0.13))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(MagpieTheme.purple)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "模型列表"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Text(String(localized: "选择这个 Agent 能看到哪些模型、顺序与自带模型"))
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 6)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                        .magpieCard(padding: 13)
                    }
                    .buttonStyle(MagpiePressableStyle())

                    actionGrid(agent)

                    if let actionMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                            Text(actionMessage)
                            Spacer(minLength: 0)
                        }
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .magpieCard(padding: 12)
                    }

                    // MARK: - 字段列表卡片
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "配置字段"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MagpieTheme.textMuted)

                        VStack(spacing: 0) {
                            ForEach(Array(agent.fields.enumerated()), id: \.element.id) { index, field in
                                NavigationLink(value: PickerRoute(agentID: agentID, fieldKey: field.key)) {
                                    fieldRow(field)
                                }
                                .buttonStyle(.plain)

                                if index < agent.fields.count - 1 {
                                    Divider()
                                        .background(MagpieTheme.borderSubtle)
                                }
                            }
                        }
                        .magpieCard(padding: 0)
                    }

                    // MARK: - 高级设置（用户自己的字段）
                    if let own = agent.own, !own.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "高级设置"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textMuted)

                            VStack(spacing: 0) {
                                ForEach(Array(own.enumerated()), id: \.element.id) { index, field in
                                    NavigationLink(value: PickerRoute(agentID: agentID, fieldKey: field.key)) {
                                        fieldRow(field)
                                    }
                                    .buttonStyle(.plain)

                                    if index < own.count - 1 {
                                        Divider()
                                            .background(MagpieTheme.borderSubtle)
                                    }
                                }
                            }
                            .magpieCard(padding: 0)
                        }
                    }

                    if agent.cliMissing == true {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(String(localized: "已找到配置文件，但未检测到对应的 CLI。安装后即可通过 magpie 启动。"))
                                .font(.caption)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(MagpieTheme.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .magpieCard(padding: 12)
                    }

                    // MARK: - 配置文件路径信息
                    if let path = agent.path {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                            Text(String(localized: "配置源：\(path)"))
                                .font(.caption)
                        }
                        .foregroundStyle(MagpieTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .magpiePageBackground()
        .navigationTitle(agent?.name ?? String(localized: "Agent"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 行操作
    private func actionGrid(_ agent: AgentDTO) -> some View {
        let canOpen = (agent.command?.isEmpty == false) || (agent.launch?.isEmpty == false)
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            actionButton(
                String(localized: "打开终端"),
                icon: "terminal.fill",
                tint: MagpieTheme.accent,
                enabled: canOpen
            ) {
                openAgent(agent)
            }
            actionButton(
                String(localized: "复制命令"),
                icon: "doc.on.doc.fill",
                tint: MagpieTheme.cyan,
                enabled: canOpen
            ) {
                copyCommand(agent)
            }
            actionButton(
                String(localized: "重启"),
                icon: "arrow.clockwise",
                tint: MagpieTheme.amber
            ) {
                restartAgent(agent)
            }
            if agent.wired == true {
                actionButton(
                    String(localized: "断开离线副本"),
                    icon: "wifi.slash",
                    tint: MagpieTheme.red
                ) {
                    disconnectOffline(agent)
                }
            } else {
                actionButton(
                    String(localized: "接入 magpie"),
                    icon: "bolt.fill",
                    tint: MagpieTheme.green
                ) {
                    agentAction(agent.id, action: "connect")
                }
            }
            if agent.drift?.field != nil {
                actionButton(
                    String(localized: "重新应用"),
                    icon: "arrow.counterclockwise",
                    tint: MagpieTheme.drift
                ) {
                    agentAction(agent.id, action: "reapply")
                }
            }
            actionButton(
                String(localized: "刷新状态"),
                icon: "arrow.triangle.2.circlepath",
                tint: MagpieTheme.textSecondary
            ) {
                Task { await app.refresh() }
            }
        }
    }

    private func actionButton(
        _ title: String,
        icon: String,
        tint: Color,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(tint)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
    }

    private func openAgent(_ agent: AgentDTO) {
        guard let client = app.client else { return }
        Task {
            if await actionVM.openAgent(client: client, id: agent.id) {
                actionMessage = String(localized: "已在服务器上打开 \(agent.name)。")
            } else {
                actionMessage = actionVM.saveError
            }
        }
    }

    private func copyCommand(_ agent: AgentDTO) {
        let command = agent.command ?? agent.launch ?? agent.typed
        guard let command, !command.isEmpty else {
            actionMessage = String(localized: "没有可复制的启动命令。")
            return
        }
        UIPasteboard.general.string = command
        actionMessage = String(localized: "启动命令已复制。")
        MagpieHaptics.success()
    }

    private func restartAgent(_ agent: AgentDTO) {
        guard let client = app.client else { return }
        Task {
            if await actionVM.restartAgent(client: client, id: agent.id) {
                await app.refresh()
                actionMessage = String(localized: "已请求重启 \(agent.name)。")
                MagpieHaptics.success()
            } else {
                actionMessage = actionVM.saveError
            }
        }
    }

    private func disconnectOffline(_ agent: AgentDTO) {
        guard let client = app.client else { return }
        Task {
            if await actionVM.disconnectOffline(client: client, id: agent.id) {
                await app.refresh()
                actionMessage = String(localized: "已断开离线副本。")
                MagpieHaptics.success()
            } else {
                actionMessage = actionVM.saveError
            }
        }
    }

    private func agentAction(_ id: String, action: String) {
        guard let client = app.client else { return }
        Task {
            do {
                let newState: StateDTO = try await client.send(
                    .post("/api/agents/\(action)/\(id)"),
                    as: StateDTO.self
                )
                app.apply(newState)
                actionMessage = String(localized: "操作已完成。")
                MagpieHaptics.success()
            } catch {
                actionMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - 头部概要
    private func headerCard(_ agent: AgentDTO) -> some View {
        HStack(spacing: 14) {
            MagpieIconView(icon: agent.icon, name: agent.name, size: 48, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(agent.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MagpieTheme.textPrimary)

                    if agent.wired == true {
                        Text(String(localized: "已接入 magpie"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MagpieTheme.greenSoft)
                            .foregroundStyle(MagpieTheme.green)
                            .clipShape(Capsule())
                    }
                }

                if let command = agent.command {
                    Text(command)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }
            Spacer()
        }
        .magpieCard()
    }

    // MARK: - 单个字段行
    private func fieldRow(_ field: FieldDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Text(field.key)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }

            Spacer()

            Text(field.value.isEmpty ? String(localized: "默认") : field.value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(field.value.isEmpty ? MagpieTheme.textMuted : MagpieTheme.accent)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
