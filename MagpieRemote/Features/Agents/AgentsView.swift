import SwiftUI
import UIKit
import SwiftData

/// Agents 页：1:1 对齐官方 Web / 客户端设计。
/// 支持 Profiles 预设切换与创建、Wired 接入控制、一键修复配置漂移（Reapply）。
struct AgentsView: View {
    @Environment(AppModel.self) private var app
    @Namespace private var zoomNamespace
    @State private var viewModel = AgentsViewModel()
    @State private var isRescanning = false
    @State private var showSaveProfileSheet = false
    @State private var newProfileName = ""
    @State private var actionError: String?
    @State private var renamingProfile: String?
    @State private var renameProfileText = ""
    @State private var showingAgentOrder = false
    @State private var showingServers = false
    @AppStorage("magpie_hide_unwired_agents") private var hideUnwired = false

    private var agents: [AgentDTO] { app.state?.agents ?? [] }
    private var visibleAgents: [AgentDTO] { hideUnwired ? agents.filter { $0.wired == true } : agents }
    private var profiles: [ProfileDTO] { app.state?.profiles ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = actionError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .magpieCard()
                    }

                    // MARK: - Profiles 快照方案横滑栏（对齐原版）
                    profilesSection

                    // MARK: - Agent 列表卡片
                    if agents.isEmpty {
                        emptyState
                    } else {
                        MagpieGlassGroup(spacing: 12) {
                            LazyVStack(spacing: 12) {
                                ForEach(visibleAgents) { agent in
                                    NavigationLink(value: AgentRoute(id: agent.id)) {
                                        AgentCard(
                                            agent: agent,
                                            onReapply: {
                                                agentAction(agent.id, action: "reapply")
                                            },
                                            onToggleWired: { turnOn in
                                                agentAction(agent.id, action: turnOn ? "connect" : "disconnect")
                                            },
                                            onOpen: {
                                                openAgent(agent)
                                            },
                                            onCopyCommand: {
                                                copyCommand(agent)
                                            },
                                            onRestart: {
                                                restartAgent(agent)
                                            },
                                            onDisconnectOffline: {
                                                disconnectOffline(agent)
                                            }
                                        )
                                    }
                                    .matchedTransitionSource(id: agent.id, in: zoomNamespace)
                                    .buttonStyle(.plain)
                                    .transition(.magpieContent)
                                }
                            }
                        }
                        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: visibleAgents.map(\.id))

                        let hiddenCount = agents.count - visibleAgents.count
                        if hiddenCount > 0 {
                            Button {
                                MagpieHaptics.light()
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { hideUnwired = false }
                            } label: {
                                Label(String(localized: "显示 \(hiddenCount) 个未接入的 Agent"), systemImage: "eye")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textMuted)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !viewModel.quotas.isEmpty {
                        quotaPanel
                    }
                    if !viewModel.groups.isEmpty {
                        routingPanel
                    }
                    if !viewModel.usageAgents.isEmpty {
                        usagePanel
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 96)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "Agents"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: AgentRoute.self) { route in
                AgentDetailView(agentID: route.id)
                    .navigationTransition(.zoom(sourceID: route.id, in: zoomNamespace))
            }
            .navigationDestination(for: PickerRoute.self) { route in
                ModelPickerView(agentID: route.agentID, fieldKey: route.fieldKey)
            }
            .refreshable {
                await app.refresh()
                if let client = app.client {
                    await viewModel.loadPanels(client: client)
                }
            }
            .task {
                if viewModel.quotas.isEmpty, let client = app.client {
                    await viewModel.loadPanels(client: client)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingServers = true
                    } label: {
                        MagpieLogoView(size: 22, showText: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "多服务器管理"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            rescanAgents()
                        } label: {
                            Label(String(localized: "重新扫描 Agent"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isRescanning)
                        Button {
                            showingAgentOrder = true
                        } label: {
                            Label(String(localized: "调整 Agent 顺序…"), systemImage: "arrow.up.arrow.down")
                        }
                        Toggle(isOn: Binding(
                            get: { hideUnwired },
                            set: { newValue in withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { hideUnwired = newValue } }
                        )) {
                            Label(String(localized: "隐藏未接入的 Agent"), systemImage: "eye.slash")
                        }
                    } label: {
                        if isRescanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "ellipsis.circle")
                                .font(.body.weight(.medium))
                        }
                    }
                    .accessibilityLabel(String(localized: "Agent 操作"))
                }
            }
            .sheet(isPresented: $showSaveProfileSheet) {
                saveProfileSheet
            }
            .alert(
                String(localized: "重命名快照"),
                isPresented: Binding(
                    get: { renamingProfile != nil },
                    set: { if !$0 { renamingProfile = nil } }
                )
            ) {
                TextField(String(localized: "新的快照名称"), text: $renameProfileText)
                Button(String(localized: "取消"), role: .cancel) { renamingProfile = nil }
                Button(String(localized: "保存")) {
                    if let from = renamingProfile {
                        renameProfile(from: from, to: renameProfileText)
                    }
                    renamingProfile = nil
                }
            }
            .sheet(isPresented: $showingAgentOrder) {
                AgentOrderSheet(agents: agents) { order in
                    await arrangeAgents(order)
                }
            }
            .sheet(isPresented: $showingServers) {
                ServerSwitcherSheet()
            }
        }
    }

    private func arrangeAgents(_ order: [String]) async -> Bool {
        guard let client = app.client else { return false }
        do {
            struct Body: Encodable { let order: [String] }
            let data = try await client.sendData(try Endpoint.post("/api/agents/arrange", body: Body(order: order)))
            if let newState = try? JSONDecoder().decode(StateDTO.self, from: data) {
                app.apply(newState)
            } else {
                await app.refresh()
            }
            MagpieHaptics.success()
            return true
        } catch {
            actionError = APIError.message(for: error)
            return false
        }
    }

    // MARK: - 行操作
    private func openAgent(_ agent: AgentDTO) {
        guard let client = app.client else { return }
        Task {
            if !(await viewModel.openAgent(client: client, id: agent.id)) {
                actionError = viewModel.saveError
            }
        }
    }

    private func copyCommand(_ agent: AgentDTO) {
        let command = agent.command ?? agent.launch ?? agent.typed
        guard let command, !command.isEmpty else {
            actionError = String(localized: "这个 Agent 没有可复制的启动命令。")
            return
        }
        UIPasteboard.general.string = command
        MagpieHaptics.success()
    }

    private func restartAgent(_ agent: AgentDTO) {
        guard let client = app.client else { return }
        Task {
            if await viewModel.restartAgent(client: client, id: agent.id) {
                await app.refresh()
                MagpieHaptics.success()
            } else {
                actionError = viewModel.saveError
            }
        }
    }

    private func disconnectOffline(_ agent: AgentDTO) {
        guard let client = app.client else { return }
        Task {
            if await viewModel.disconnectOffline(client: client, id: agent.id) {
                await app.refresh()
                MagpieHaptics.success()
            } else {
                actionError = viewModel.saveError
            }
        }
    }

    // MARK: - 配额面板
    private var quotaPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            MagpieSectionLabel(
                title: String(localized: "服务商配额"),
                detail: "\(viewModel.quotas.count)"
            )

            VStack(spacing: 0) {
                ForEach(Array(viewModel.quotas.prefix(3).enumerated()), id: \.offset) { item in
                    let index = item.offset
                    let quota = item.element
                    HStack(spacing: 10) {
                        MagpieIconView(icon: quota.icon ?? quota.provider, name: quota.name, size: 28, cornerRadius: 6)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text(quota.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                    .lineLimit(1)
                                if let balance = quota.balance, !balance.isEmpty {
                                    MagpieStatusChip(text: balance, color: MagpieTheme.green)
                                }
                            }

                            if let window = quota.creditSummaryWindow ?? quota.windows?.first {
                                HStack(spacing: 5) {
                                    ProgressView(value: window.percentUsed, total: 100)
                                        .tint(window.percentUsed > 80 ? MagpieTheme.red : MagpieTheme.accent)
                                    if window.isCreditCount, let left = window.leftAmount {
                                        Text(String(localized: "可用 \(QuotaFormat.amount(left))"))
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundStyle(MagpieTheme.textMuted)
                                    } else {
                                        Text(window.percentText)
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundStyle(MagpieTheme.textMuted)
                                    }
                                }
                            } else {
                                Text(quota.user.map { "\(quota.provider) · \($0)" } ?? quota.provider)
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < min(viewModel.quotas.count, 3) - 1 {
                        Divider().background(MagpieTheme.borderSubtle).padding(.leading, 52)
                    }
                }
            }
            .magpieCard(padding: 0)
        }
    }

    // MARK: - 路由面板
    private var routingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            MagpieSectionLabel(
                title: String(localized: "路由组"),
                detail: "\(viewModel.groups.count)"
            )

            VStack(spacing: 0) {
                ForEach(Array(viewModel.groups.prefix(4).enumerated()), id: \.element.id) { item in
                    let index = item.offset
                    let group = item.element
                    HStack(spacing: 10) {
                        Image(systemName: group.isAuto ? "wand.and.stars" : "square.3.layers.3d")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(group.isAuto ? MagpieTheme.accent : MagpieTheme.cyan)
                            .frame(width: 30, height: 30)
                            .background(MagpieTheme.pill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(group.members?.count ?? 0) 个成员")
                                .font(.caption2)
                                .foregroundStyle(MagpieTheme.textMuted)
                        }

                        Spacer()

                        Text(group.routingDisplayName)
                            .font(.system(size: 9.5, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MagpieTheme.accentSoft)
                            .foregroundStyle(MagpieTheme.accent)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < min(viewModel.groups.count, 4) - 1 {
                        Divider().background(MagpieTheme.borderSubtle).padding(.leading, 54)
                    }
                }
            }
            .magpieCard(padding: 0)
        }
    }

    // MARK: - 用量面板
    private var usagePanel: some View {
        let agents = viewModel.usageAgents.sorted { $0.totalTokens > $1.totalTokens }
        return VStack(alignment: .leading, spacing: 8) {
            MagpieSectionLabel(
                title: String(localized: "Agent 用量"),
                detail: String(localized: "最近 30 天")
            )

            VStack(spacing: 0) {
                ForEach(Array(agents.prefix(5).enumerated()), id: \.offset) { item in
                    let index = item.offset
                    let group = item.element
                    HStack(spacing: 10) {
                        MagpieIconView(icon: group.icon, name: group.displayName, size: 28, cornerRadius: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(group.calls ?? 0) 次调用")
                                .font(.caption2)
                                .foregroundStyle(MagpieTheme.textMuted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(UsageDTO.formatTokens(group.totalTokens))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            Text(group.formattedCost)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(MagpieTheme.green)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < min(agents.count, 5) - 1 {
                        Divider().background(MagpieTheme.borderSubtle).padding(.leading, 52)
                    }
                }
            }
            .magpieCard(padding: 0)
        }
    }

    // MARK: - Profiles 横滑栏
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "PROFILES 方案快照"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textMuted)

                Spacer()

                Button {
                    newProfileName = ""
                    showSaveProfileSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text(String(localized: "保存快照"))
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(MagpieTheme.accent)
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(profiles) { profile in
                        Button {
                            useProfile(profile.name)
                        } label: {
                            HStack(spacing: 6) {
                                if profile.inUse == true {
                                    MagpiePulseDot(color: MagpieTheme.accent)
                                }
                                Text(profile.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                if let summary = profile.summary {
                                    Text(summary)
                                        .font(.caption2)
                                        .foregroundStyle(profile.inUse == true ? MagpieTheme.accent : MagpieTheme.textMuted)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .magpieChip(isSelected: profile.inUse == true)
                            .frame(maxWidth: 250, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renamingProfile = profile.name
                                renameProfileText = profile.name
                            } label: {
                                Label(String(localized: "重命名快照…"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteProfile(profile.name)
                            } label: {
                                Label(String(localized: "删除快照"), systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        newProfileName = ""
                        showSaveProfileSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text(String(localized: "新建"))
                        }
                        .magpieChip(isSelected: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveProfileSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "例如 Work / CodeReview"), text: $newProfileName)
                } header: {
                    Text(String(localized: "快照名称"))
                } footer: {
                    Text(String(localized: "保存当前所有 Agent 的模型与接入配置，方便日后一键恢复切换。"))
                }
            }
            .navigationTitle(String(localized: "保存当前快照"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { showSaveProfileSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存")) {
                        saveProfile(newProfileName)
                    }
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 0.8))
                    .shadow(color: MagpieTheme.accent.opacity(0.1), radius: 10, y: 4)
                Image(systemName: "terminal")
                    .font(.system(size: 28))
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            Text(String(localized: "未检测到编码 Agent"))
                .font(.headline)
                .foregroundStyle(MagpieTheme.textPrimary)
            Text(String(localized: "当前 magpie 所在设备上尚未检测到 Claude Code、Codex、Gemini CLI 等支持的 Agent。"))
                .font(.subheadline)
                .foregroundStyle(MagpieTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - API 操作
    private func useProfile(_ name: String) {
        guard let client = app.client else { return }
        MagpieHaptics.light()
        Task {
            struct UseBody: Encodable { var Name: String }
            do {
                let newState: StateDTO = try await client.send(.post("/api/profile/use", body: UseBody(Name: name)), as: StateDTO.self)
                app.apply(newState)
                MagpieHaptics.success()
            } catch {
                actionError = APIError.message(for: error)
            }
        }
    }

    private func saveProfile(_ name: String) {
        guard let client = app.client else { return }
        Task {
            struct SaveBody: Encodable { var Name: String }
            do {
                let newState: StateDTO = try await client.send(.post("/api/profile/save", body: SaveBody(Name: name)), as: StateDTO.self)
                app.apply(newState)
                showSaveProfileSheet = false
                MagpieHaptics.success()
            } catch {
                actionError = APIError.message(for: error)
            }
        }
    }

    private func renameProfile(from: String, to: String) {
        guard let client = app.client else { return }
        let newName = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != from else { return }
        Task {
            struct RenameBody: Encodable {
                var Name: String
                var To: String
            }
            do {
                let newState: StateDTO = try await client.send(
                    .post("/api/profile/rename", body: RenameBody(Name: from, To: newName)),
                    as: StateDTO.self
                )
                app.apply(newState)
                MagpieHaptics.success()
            } catch {
                actionError = APIError.message(for: error)
            }
        }
    }

    private func deleteProfile(_ name: String) {
        guard let client = app.client else { return }
        Task {
            struct DelBody: Encodable { var Name: String }
            do {
                let newState: StateDTO = try await client.send(.post("/api/profile/delete", body: DelBody(Name: name)), as: StateDTO.self)
                app.apply(newState)
            } catch {
                actionError = APIError.message(for: error)
            }
        }
    }

    private func agentAction(_ id: String, action: String) {
        guard let client = app.client else { return }
        MagpieHaptics.medium()
        Task {
            do {
                let newState: StateDTO = try await client.send(.post("/api/agents/\(action)/\(id)"), as: StateDTO.self)
                app.apply(newState)
                MagpieHaptics.success()
            } catch {
                actionError = APIError.message(for: error)
            }
        }
    }

    private func rescanAgents() {
        guard let client = app.client else { return }
        isRescanning = true
        Task {
            defer { isRescanning = false }
            do {
                let newState: StateDTO = try await client.send(.post("/api/agents/rescan"), as: StateDTO.self)
                app.apply(newState)
            } catch {
                await app.refresh()
            }
        }
    }
}

// MARK: - Agent 排序
private struct AgentOrderSheet: View {
    let agents: [AgentDTO]
    let onSave: ([String]) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var items: [AgentDTO] = []
    @State private var working = false
    @State private var errorMessage: String?
    @State private var primed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, agent in
                        HStack(spacing: 10) {
                            MagpieIconView(icon: agent.icon, name: agent.name, size: 26, cornerRadius: 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Text(agent.id)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }
                            Spacer()
                            Button {
                                move(index, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .foregroundStyle(index == 0 ? MagpieTheme.textMuted.opacity(0.3) : MagpieTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            Button {
                                move(index, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .foregroundStyle(index == items.count - 1 ? MagpieTheme.textMuted.opacity(0.3) : MagpieTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == items.count - 1)
                        }
                    }
                } footer: {
                    Text(String(localized: "顺序即 Agents 页与菜单栏面板的展示顺序。"))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.red)
                    }
                }
            }
            .navigationTitle(String(localized: "Agent 顺序"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if working {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "保存")).fontWeight(.semibold)
                        }
                    }
                    .disabled(working)
                }
            }
            .onAppear {
                guard !primed else { return }
                primed = true
                items = agents
            }
        }
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard items.indices.contains(index), items.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            items.swapAt(index, target)
        }
        MagpieHaptics.light()
    }

    private func save() {
        working = true
        errorMessage = nil
        Task {
            let ok = await onSave(items.map(\.id))
            working = false
            if ok { dismiss() } else { errorMessage = String(localized: "保存失败，请稍后再试。") }
        }
    }
}

// MARK: - 原版风格 Agent 卡片
private struct AgentCard: View {
    let agent: AgentDTO
    var onReapply: () -> Void
    var onToggleWired: (Bool) -> Void
    var onOpen: () -> Void
    var onCopyCommand: () -> Void
    var onRestart: () -> Void
    var onDisconnectOffline: () -> Void

    private var primaryModel: String {
        agent.fields.first { $0.key == "model" }?.value ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MagpieIconView(icon: agent.icon, name: agent.name, size: 36, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(agent.name)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(MagpieTheme.textPrimary)

                        if agent.wired == true {
                            HStack(spacing: 4) {
                                MagpiePulseDot(color: MagpieTheme.green)
                                Text(String(localized: "已接入"))
                            }
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MagpieTheme.greenSoft)
                            .foregroundStyle(MagpieTheme.green)
                            .clipShape(Capsule())
                        } else if let source = agent.source, !source.isEmpty {
                            Text(source)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MagpieTheme.pill)
                                .foregroundStyle(MagpieTheme.textMuted)
                                .clipShape(Capsule())
                        }

                        if agent.failover == true {
                            Text(String(localized: "故障转移"))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MagpieTheme.cyan.opacity(0.13))
                                .foregroundStyle(MagpieTheme.cyan)
                                .clipShape(Capsule())
                        }
                        if agent.appOut != nil {
                            Text(String(localized: "额度用尽"))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MagpieTheme.amberSoft)
                                .foregroundStyle(MagpieTheme.amber)
                                .clipShape(Capsule())
                        }
                        if agent.joined == true {
                            Text(String(localized: "自带模型"))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MagpieTheme.greenSoft)
                                .foregroundStyle(MagpieTheme.green)
                                .clipShape(Capsule())
                        }
                    }

                    if let path = agent.path {
                        Text(path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(MagpieTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // 快捷接入开关
                Button {
                    MagpieHaptics.light()
                    onToggleWired(!(agent.wired ?? false))
                } label: {
                    Image(systemName: agent.wired == true ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(agent.wired == true ? MagpieTheme.green : MagpieTheme.textMuted)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textMuted)
            }

            Divider()
                .background(MagpieTheme.borderSubtle)

            // 底部当前配置模型与状态提示
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(String(localized: "模型:"))
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textMuted)
                    Text(primaryModel.isEmpty ? String(localized: "默认") : primaryModel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(primaryModel.isEmpty ? MagpieTheme.textMuted : MagpieTheme.accent)
                        .lineLimit(1)
                }

                Spacer()

                if let drift = agent.drift, drift.field != nil {
                    Button {
                        MagpieHaptics.medium()
                        onReapply()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                            Text(String(localized: "恢复设置"))
                        }
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MagpieTheme.driftSoft)
                        .foregroundStyle(MagpieTheme.drift)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if let stale = agent.stale, stale > 0 {
                    Text(String(localized: "\(stale) 副本待重启"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.amber)
                }
            }
        }
        .magpieLiquidCard(padding: 14, cornerRadius: 20)
        .contextMenu {
            if agent.command?.isEmpty == false || agent.launch?.isEmpty == false {
                Button(action: onOpen) {
                    Label(String(localized: "打开终端"), systemImage: "terminal")
                }
                Button(action: onCopyCommand) {
                    Label(String(localized: "复制启动命令"), systemImage: "doc.on.doc")
                }
            }
            if agent.drift?.field != nil {
                Button(action: onReapply) {
                    Label(String(localized: "重新应用设置"), systemImage: "arrow.counterclockwise")
                }
            }
            Button(action: onRestart) {
                Label(String(localized: "重启 Agent"), systemImage: "arrow.clockwise")
            }
            if agent.wired == true {
                Button(action: onDisconnectOffline) {
                    Label(String(localized: "断开离线副本"), systemImage: "wifi.slash")
                }
                Button(role: .destructive) {
                    onToggleWired(false)
                } label: {
                    Label(String(localized: "断开 magpie"), systemImage: "bolt.slash")
                }
            } else {
                Button {
                    onToggleWired(true)
                } label: {
                    Label(String(localized: "接入 magpie"), systemImage: "bolt.fill")
                }
            }
        }
    }
}

// MARK: - 多服务器管理
private struct ServerSwitcherSheet: View {
    @Query(sort: \Connection.sortOrder) private var connections: [Connection]
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingAdd = false
    @State private var editing: Connection?
    @State private var switchingID: UUID?
    @State private var errorMessage: String?

    private var activeConnection: Connection? {
        connections.first { $0.id == app.activeID }
    }

    private var others: [Connection] {
        connections.filter { $0.id != app.activeID }
    }

    var body: some View {
        NavigationStack {
            List {
                if let active = activeConnection {
                    Section {
                        serverRow(active, active: true)
                    } header: {
                        Text(String(localized: "当前服务器"))
                    }
                }

                if !others.isEmpty {
                    Section {
                        ForEach(others) { connection in
                            Button {
                                switchTo(connection)
                            } label: {
                                serverRow(connection, active: false)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    delete(connection)
                                } label: {
                                    Label(String(localized: "删除"), systemImage: "trash")
                                }
                                Button {
                                    editing = connection
                                } label: {
                                    Label(String(localized: "编辑"), systemImage: "pencil")
                                }
                                .tint(MagpieTheme.accent)
                            }
                        }
                    } header: {
                        Text(String(localized: "其他服务器"))
                    }
                }

                Section {
                    Button {
                        showingAdd = true
                    } label: {
                        Label(String(localized: "添加服务器"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MagpieTheme.accent)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.red)
                    }
                }
            }
            .navigationTitle(String(localized: "多服务器管理"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ConnectionEditView()
            }
            .sheet(item: $editing) { connection in
                ConnectionEditView(editing: connection)
            }
            .overlay {
                if switchingID != nil {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(String(localized: "正在切换服务器…"))
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.textSecondary)
                    }
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func serverRow(_ connection: Connection, active: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? MagpieTheme.accentSoft : MagpieTheme.pill)
                    .frame(width: 38, height: 38)
                Image(systemName: active ? "server.rack" : "server.rack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(active ? MagpieTheme.accent : MagpieTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(connection.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    if active {
                        MagpieStatusChip(text: String(localized: "已连接"), color: MagpieTheme.green)
                    }
                }
                Text(connection.urlString)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            if active {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MagpieTheme.green)
            } else if switchingID == connection.id {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
    }

    private func switchTo(_ connection: Connection) {
        guard switchingID == nil else { return }
        switchingID = connection.id
        errorMessage = nil
        Task {
            await app.activate(
                id: connection.id,
                name: connection.name,
                urlString: connection.urlString
            )
            switchingID = nil
            if app.isConnected {
                dismiss()
            } else {
                errorMessage = app.errorMessage ?? String(localized: "无法连接到这个服务器。")
            }
        }
    }

    private func delete(_ connection: Connection) {
        let wasActive = connection.id == app.activeID
        KeychainStore.delete(for: connection.id.uuidString)
        context.delete(connection)
        try? context.save()
        if wasActive {
            app.disconnect()
            dismiss()
        }
    }
}
