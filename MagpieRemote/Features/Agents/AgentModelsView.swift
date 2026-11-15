import SwiftUI

/// per-Agent 模型列表：对齐官方「Showing n / m models」面板。
/// All / Shown / Order 三个视图，点按即时保存；支持仅我选的、隐藏自带模型、
/// 全部显示/隐藏与自定义顺序。
struct AgentModelsView: View {
    let agentID: String

    @Environment(AppModel.self) private var app
    @State private var viewModel = AgentModelsViewModel()
    @State private var mode: Mode = .all
    @State private var searchText = ""
    @State private var editMode: EditMode = .active

    enum Mode: String, CaseIterable, Identifiable {
        case all
        case shown
        case order

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return String(localized: "全部")
            case .shown: return String(localized: "已显示")
            case .order: return String(localized: "顺序")
            }
        }
    }

    private var agentName: String {
        app.state?.agents.first { $0.id == agentID }?.name ?? agentID
    }

    private var filteredModels: [AgentModelDTO] {
        var list = viewModel.models
        if mode == .shown {
            list = list.filter { !$0.isHidden }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return list }
        return list.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.id.localizedCaseInsensitiveContains(query)
                || $0.groupName.localizedCaseInsensitiveContains(query)
        }
    }

    private var groupedModels: [(group: String, models: [AgentModelDTO])] {
        let dict = Dictionary(grouping: filteredModels, by: \.groupName)
        return dict.keys.sorted().map { key in
            (key, dict[key]!.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
        }
    }

    private var orderedModels: [AgentModelDTO] {
        let byID = Dictionary(uniqueKeysWithValues: filteredModels.map { ($0.id, $0) })
        let order = viewModel.orderedList(visibleIDs: [])
        return order.compactMap { byID[$0] }
    }

    private var visibleCount: Int {
        viewModel.models.filter { !$0.isHidden }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            HStack {
                Text(String(localized: "显示 \(visibleCount) / \(viewModel.models.count) 个模型"))
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textMuted)
                if viewModel.only {
                    MagpieStatusChip(text: String(localized: "仅我选的"), color: MagpieTheme.accent)
                }
                if viewModel.ownHidden {
                    MagpieStatusChip(text: String(localized: "已隐藏自带"), color: MagpieTheme.amber)
                }
                Spacer()
                if viewModel.isSaving {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            if viewModel.isLoading && viewModel.models.isEmpty {
                ProgressView(String(localized: "读取模型列表…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredModels.isEmpty {
                ContentUnavailableView(
                    String(localized: "没有匹配的模型"),
                    systemImage: "square.grid.2x2",
                    description: Text(String(localized: "换一个关键词，或把视图切到「全部」。"))
                )
                .frame(maxHeight: .infinity)
            } else {
                modelList
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .magpiePageBackground()
        .navigationTitle(String(localized: "模型列表"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: String(localized: "搜索模型或提供方…"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle(String(localized: "仅我选的模型"), isOn: Binding(
                        get: { viewModel.only },
                        set: { on in
                            guard let client = app.client else { return }
                            Task { await viewModel.setOnly(client: client, agentID: agentID, on: on) }
                        }
                    ))

                    Toggle(String(localized: "隐藏 Agent 自带模型"), isOn: Binding(
                        get: { viewModel.ownHidden },
                        set: { on in
                            guard let client = app.client else { return }
                            Task { await viewModel.setOwnHidden(client: client, agentID: agentID, on: on) }
                        }
                    ))

                    Divider()

                    Button(String(localized: "全部显示")) {
                        showAll()
                    }
                    Button(String(localized: "全部隐藏")) {
                        hideAll()
                    }
                    Button(String(localized: "恢复默认顺序")) {
                        guard let client = app.client else { return }
                        Task { await viewModel.setOrder(client: client, agentID: agentID, order: []) }
                    }

                    Divider()

                    Button(String(localized: "重新检测")) {
                        load()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            if mode == .order {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: mode) { _, newMode in
            editMode = newMode == .order ? .active : .inactive
        }
        .task {
            if viewModel.models.isEmpty { load() }
        }
        .refreshable {
            if let client = app.client {
                await viewModel.load(client: client, agentID: agentID)
            }
        }
    }

    @ViewBuilder
    private var modelList: some View {
        if mode == .order {
            List {
                Section {
                    ForEach(orderedModels) { model in
                        row(model)
                    }
                    .onMove { source, destination in
                        viewModel.moveOrder(
                            from: source,
                            to: destination,
                            visibleIDs: []
                        )
                        saveOrder()
                    }
                } footer: {
                    Text(String(localized: "顺序决定这个 Agent 的模型选择器里的排列。"))
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        } else {
            List {
                ForEach(groupedModels.indices, id: \.self) { index in
                    let section = groupedModels[index]
                    Section(section.group) {
                        ForEach(section.models) { model in
                            row(model)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
    }

    private func row(_ model: AgentModelDTO) -> some View {
        Button {
            toggle(model)
        } label: {
            HStack(spacing: 11) {
                MagpieIconView(
                    icon: model.icon ?? model.logo,
                    name: model.groupName,
                    size: 26,
                    cornerRadius: 6
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(model.displayName)
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(model.isHidden ? MagpieTheme.textMuted : MagpieTheme.textPrimary)
                            .lineLimit(1)
                        if model.inUse == true {
                            MagpieStatusChip(text: String(localized: "使用中"), color: MagpieTheme.green)
                        }
                        if model.own == true {
                            MagpieStatusChip(text: String(localized: "自带"), color: MagpieTheme.cyan)
                        }
                        if let kept = model.kept, !kept.isEmpty {
                            MagpieStatusChip(text: kept.joined(separator: "/"), color: MagpieTheme.purple)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(model.id)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(MagpieTheme.textMuted)
                            .lineLimit(1)
                        if let context = model.context, context > 0 {
                            Text(UsageDTO.formatTokens(context))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textMuted.opacity(0.85))
                        }
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: model.isHidden ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(model.isHidden ? MagpieTheme.textMuted.opacity(0.55) : MagpieTheme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ model: AgentModelDTO) {
        guard let client = app.client else { return }
        Task {
            if viewModel.only {
                var shown = Set(viewModel.models.filter { !$0.isHidden }.map(\.id))
                if shown.contains(model.id) {
                    shown.remove(model.id)
                } else {
                    shown.insert(model.id)
                }
                await viewModel.setShown(client: client, agentID: agentID, shown: Array(shown).sorted())
            } else {
                var hidden = Set(viewModel.models.filter { $0.isHidden }.map(\.id))
                if hidden.contains(model.id) {
                    hidden.remove(model.id)
                } else {
                    hidden.insert(model.id)
                }
                await viewModel.setHidden(client: client, agentID: agentID, hidden: Array(hidden).sorted())
            }
        }
    }

    private func showAll() {
        guard let client = app.client else { return }
        Task {
            if viewModel.only {
                await viewModel.setShown(
                    client: client,
                    agentID: agentID,
                    shown: viewModel.models.map(\.id).sorted()
                )
            } else {
                await viewModel.widen(
                    client: client,
                    agentID: agentID,
                    ids: viewModel.models.map(\.id)
                )
                await viewModel.setHidden(client: client, agentID: agentID, hidden: [])
            }
        }
    }

    private func hideAll() {
        guard let client = app.client else { return }
        Task {
            if viewModel.only {
                await viewModel.setShown(client: client, agentID: agentID, shown: [])
            } else {
                await viewModel.setHidden(
                    client: client,
                    agentID: agentID,
                    hidden: viewModel.models.map(\.id).sorted()
                )
            }
        }
    }

    private func saveOrder() {
        guard let client = app.client else { return }
        Task {
            await viewModel.setOrder(
                client: client,
                agentID: agentID,
                order: viewModel.orderedList(visibleIDs: [])
            )
        }
    }

    private func load() {
        guard let client = app.client else { return }
        Task { await viewModel.load(client: client, agentID: agentID) }
    }
}
