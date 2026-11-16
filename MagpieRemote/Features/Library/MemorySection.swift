import SwiftUI

/// Library › Memory：记忆列表、建议确认、蒸馏与语义检索设置。
struct MemorySection: View {
    @Environment(AppModel.self) private var app
    @State private var viewModel = MemoryViewModel()

    @State private var query = ""
    @State private var status = "active"
    @State private var scope = ""
    @State private var editing: MemoryDTO?
    @State private var creating = false
    @State private var primed = false

    private var visibleMemories: [MemoryDTO] {
        var list = viewModel.memories.filter { ($0.status ?? "active") == status }
        if !scope.isEmpty {
            list = list.filter { ($0.scope ?? "global") == scope }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            list = list.filter {
                ($0.text ?? "").lowercased().contains(q)
                    || ($0.why ?? "").lowercased().contains(q)
                    || ($0.tags ?? []).joined(separator: " ").lowercased().contains(q)
            }
        }
        // 语义排序优先；否则固定在前、最近更新在前。
        if !viewModel.rankedIDs.isEmpty {
            let order = Dictionary(uniqueKeysWithValues: viewModel.rankedIDs.enumerated().map { ($1, $0) })
            list.sort { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        } else {
            list.sort {
                if ($0.pinned ?? false) != ($1.pinned ?? false) {
                    return ($0.pinned ?? false) && !($1.pinned ?? false)
                }
                return ($0.updated ?? $0.created ?? "") > ($1.updated ?? $1.created ?? "")
            }
        }
        return list
    }

    private var scopes: [(String, String)] {
        var out: [(String, String)] = [("", String(localized: "全部范围")), ("global", String(localized: "所有项目"))]
        for key in viewModel.projects.keys.sorted() {
            out.append(("project:\(key)", viewModel.projects[key]?.name ?? key))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 16) {
            digestCard
            distillCard
            semanticCard
            suggestionsCard
            listHeader
            memoryList
        }
        .task {
            guard !primed else { return }
            primed = true
            await reload()
        }
        .sheet(item: $editing) { memory in
            MemoryEditSheet(memory: memory) { text, why, tags, kind, scope in
                guard let client = app.client else { return false }
                return await viewModel.save(
                    client: client,
                    id: memory.id,
                    text: text,
                    why: why,
                    tags: tags,
                    kind: kind,
                    scope: scope
                )
            }
        }
        .sheet(isPresented: $creating) {
            MemoryEditSheet(memory: nil) { text, why, tags, kind, scope in
                guard let client = app.client else { return false }
                return await viewModel.save(
                    client: client,
                    id: nil,
                    text: text,
                    why: why,
                    tags: tags,
                    kind: kind,
                    scope: scope
                )
            }
        }
    }

    // MARK: - 摘要开关

    private var digestCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MagpieTheme.purple)
                .frame(width: 34, height: 34)
                .background(MagpieTheme.purple.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "写进 Agent 指令"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Text(String(localized: "勾选的 Agent 会读到记忆摘要"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { viewModel.digestOn },
                set: { on in
                    guard let client = app.client else { return }
                    Task { await viewModel.setDigest(client: client, on: on) }
                }
            ))
            .labelsHidden()
            .tint(MagpieTheme.purple)
        }
        .magpieCard(padding: 14, cornerRadius: 18)
    }

    // MARK: - 蒸馏

    private var distillCard: some View {
        let distill = viewModel.distill
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MagpieTheme.cyan)
                    .frame(width: 34, height: 34)
                    .background(MagpieTheme.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "从对话中学习"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(String(localized: "后台阅读会话，把值得记住的写进记忆"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { distill?.on ?? false },
                    set: { on in
                        guard let client = app.client else { return }
                        Task {
                            await viewModel.setDistill(
                                client: client,
                                on: on,
                                model: distill?.model ?? "",
                                days: distill?.days
                            )
                        }
                    }
                ))
                .labelsHidden()
                .tint(MagpieTheme.cyan)
            }

            if let distill, distill.on == true {
                if let running = distill.running, running {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(progressText(distill))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                        Spacer()
                        Button(String(localized: "停止")) {
                            guard let client = app.client else { return }
                            Task { await viewModel.stopDistill(client: client) }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(MagpieTheme.red)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(distillLine(distill))
                            .font(.caption2)
                            .foregroundStyle(distill.error == nil ? MagpieTheme.textMuted : MagpieTheme.red)
                            .lineLimit(2)
                        Spacer()
                        Button(String(localized: "立即读取")) {
                            guard let client = app.client else { return }
                            Task { await viewModel.runDistill(client: client) }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(MagpieTheme.cyan)
                    }
                }

                // 模型 / 思考强度 / 回读范围
                HStack(spacing: 8) {
                    Menu {
                        Button(String(localized: "自动")) {
                            setDistill(model: "")
                        }
                        ForEach(distill.models ?? []) { model in
                            Button(model.displayName) {
                                setDistill(model: model.id ?? "")
                            }
                        }
                    } label: {
                        distillChip(modelLabel(distill))
                    }

                    if let efforts = distill.efforts, !efforts.isEmpty {
                        Menu {
                            Button(String(localized: "默认")) { setDistill(effort: "") }
                            ForEach(efforts, id: \.self) { level in
                                Button(level) { setDistill(effort: level) }
                            }
                        } label: {
                            distillChip(distill.effort ?? String(localized: "默认"))
                        }
                    }

                    Menu {
                        ForEach(distill.ranges ?? [7, 30, 90, 365, -1], id: \.self) { days in
                            Button(rangeLabel(days)) { setDistill(days: days) }
                        }
                    } label: {
                        distillChip(rangeLabel(distill.days ?? 7))
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .magpieCard(padding: 14, cornerRadius: 18)
    }

    private func distillChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(MagpieTheme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .magpieLiquidSurface(cornerRadius: 999)
    }

    private func modelLabel(_ distill: MemoryDistillDTO) -> String {
        if let model = distill.model, !model.isEmpty {
            return distill.models?.first { $0.id == model }?.displayName ?? model
        }
        if let auto = distill.auto, !auto.isEmpty {
            let name = distill.models?.first { $0.id == auto }?.displayName ?? auto
            return String(localized: "自动 · ") + name
        }
        return String(localized: "自动")
    }

    private func rangeLabel(_ days: Int) -> String {
        switch days {
        case -1: return String(localized: "全部")
        case 365: return String(localized: "1 年")
        default: return String(localized: "\(days) 天")
        }
    }

    private func progressText(_ distill: MemoryDistillDTO) -> String {
        if let doing = distill.doing, let of = distill.of, of > 0 {
            return String(localized: "正在阅读 \(doing)/\(of)")
        }
        return String(localized: "正在阅读…")
    }

    private func distillLine(_ distill: MemoryDistillDTO) -> String {
        if let error = distill.error, !error.isEmpty {
            return String(localized: "上次中断：") + error
        }
        if let last = distill.last, !last.isEmpty {
            return String(localized: "上次读取 ") + last
        }
        return String(localized: "每小时读取安静 30 分钟以上的对话")
    }

    private func setDistill(model: String? = nil, effort: String? = nil, days: Int? = nil) {
        guard let client = app.client, let distill = viewModel.distill else { return }
        Task {
            await viewModel.setDistill(
                client: client,
                on: distill.on ?? false,
                model: model ?? distill.model ?? "",
                effort: effort,
                days: days
            )
        }
    }

    // MARK: - 语义检索

    private var semanticCard: some View {
        let semantic = viewModel.semantic
        let status: String = {
            guard let semantic else { return String(localized: "用本地嵌入模型按意思而不是字面匹配") }
            if semantic.downloading == true {
                if let done = semantic.done, let of = semantic.of, of > 0 {
                    return String(localized: "正在下载模型 \(done)/\(of)")
                }
                return String(localized: "正在下载模型…")
            }
            if semantic.installed == true {
                if let size = semantic.size, size > 0 {
                    return String(localized: "本地模型已就绪 · ") + ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                }
                return String(localized: "本地模型已就绪")
            }
            return String(localized: "开启后会下载本地嵌入模型")
        }()
        return HStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MagpieTheme.amber)
                .frame(width: 34, height: 34)
                .background(MagpieTheme.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "按含义搜索"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { semantic?.on ?? false },
                set: { on in
                    guard let client = app.client else { return }
                    Task { await viewModel.setSemantic(client: client, on: on) }
                }
            ))
            .labelsHidden()
            .tint(MagpieTheme.amber)
        }
        .magpieCard(padding: 14, cornerRadius: 18)
    }

    // MARK: - 建议

    @ViewBuilder
    private var suggestionsCard: some View {
        let suggestions = viewModel.data?.suggestions ?? []
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MagpieSectionLabel(
                    title: String(localized: "待确认"),
                    detail: String(localized: "Agent 猜测的记忆，确认后才会生效")
                )

                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                    VStack(alignment: .leading, spacing: 10) {
                        if let text = suggestion.text, !text.isEmpty {
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let projects = suggestion.projects, !projects.isEmpty {
                            Text(String(localized: "学到于 ") + projects.map { viewModel.projects[$0]?.name ?? $0 }.joined(separator: "、"))
                                .font(.caption2)
                                .foregroundStyle(MagpieTheme.textMuted)
                        }

                        HStack(spacing: 8) {
                            if let ids = suggestion.ids, !ids.isEmpty {
                                Button(String(localized: "全局保留")) {
                                    guard let client = app.client else { return }
                                    Task { await viewModel.promote(client: client, ids: ids) }
                                }
                                .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.green))

                                if ids.count == 1 {
                                    Button(String(localized: "做成技能")) {
                                        guard let client = app.client else { return }
                                        Task { await viewModel.makeSkill(client: client, id: ids[0]) }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MagpieTheme.purple)
                                }
                            }

                            Spacer()

                            if let key = suggestion.key {
                                Button(String(localized: "暂不需要")) {
                                    guard let client = app.client else { return }
                                    Task { await viewModel.decline(client: client, key: key) }
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(MagpieTheme.textMuted)
                            }
                        }
                    }
                    .magpieCard(padding: 14, cornerRadius: 18)
                }
            }
        }
    }

    // MARK: - 列表头

    private var listHeader: some View {
        VStack(spacing: 10) {
            HStack {
                MagpieSectionLabel(
                    title: String(localized: "记忆"),
                    detail: String(localized: "\(visibleMemories.count) 条")
                )
                Spacer()
                Button {
                    creating = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text(String(localized: "新建"))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.accent)
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $status) {
                Text(String(localized: "活跃")).tag("active")
                Text(String(localized: "待确认")).tag("candidate")
                Text(String(localized: "已归档")).tag("archived")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textMuted)
                TextField(String(localized: "搜索记忆…"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { rankNow() }
                if !query.isEmpty {
                    Button {
                        query = ""
                        viewModel.rankedIDs = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .magpieLiquidSurface(cornerRadius: 11)

            if scopes.count > 2 {
                Menu {
                    ForEach(Array(scopes.enumerated()), id: \.offset) { _, item in
                        Button(item.1) { scope = item.0 }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(scopes.first { $0.0 == scope }?.1 ?? String(localized: "全部范围"))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(scope.isEmpty ? MagpieTheme.textSecondary : MagpieTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .magpieLiquidSurface(cornerRadius: 999)
                }
            }
        }
        .onChange(of: status) { _, _ in rankNow() }
    }

    // MARK: - 列表

    @ViewBuilder
    private var memoryList: some View {
        if viewModel.isLoading && viewModel.memories.isEmpty {
            ProgressView(String(localized: "读取记忆…"))
                .padding(.vertical, 30)
        } else if visibleMemories.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "brain")
                    .font(.system(size: 26))
                    .foregroundStyle(MagpieTheme.textMuted)
                Text(String(localized: "还没有记忆"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textSecondary)
                Text(String(localized: "Agent 通过 Magpie Memory 保存，或打开「从对话中学习」自动积累。"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(visibleMemories) { memory in
                    memoryRow(memory)
                }
            }
        }
    }

    private func memoryRow(_ memory: MemoryDTO) -> some View {
        let kind = MemoryKind(rawValue: memory.kind ?? "") ?? .fact
        return Button {
            editing = memory
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MagpieTheme.accent)
                    Text(kind.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MagpieTheme.accent)
                    if memory.pinned ?? false {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(MagpieTheme.amber)
                    }
                    Spacer()
                    Text(scopeLabel(memory.scope))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Text(memory.text ?? "")
                    .font(.subheadline)
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let tags = memory.tags, !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .magpieCard(padding: 14, cornerRadius: 18)
        }
        .buttonStyle(MagpiePressableStyle())
        .contextMenu {
            Button {
                guard let client = app.client else { return }
                Task { await viewModel.togglePin(client: client, memory: memory) }
            } label: {
                Label(
                    memory.pinned ?? false ? String(localized: "取消固定") : String(localized: "固定"),
                    systemImage: memory.pinned ?? false ? "pin.slash" : "pin"
                )
            }

            if (memory.status ?? "active") == "active" {
                Button {
                    guard let client = app.client else { return }
                    Task { await viewModel.setStatus(client: client, id: memory.id, status: "archived") }
                } label: {
                    Label(String(localized: "归档"), systemImage: "archivebox")
                }
            } else {
                Button {
                    guard let client = app.client else { return }
                    Task { await viewModel.setStatus(client: client, id: memory.id, status: "active") }
                } label: {
                    Label(String(localized: "恢复"), systemImage: "arrow.uturn.backward")
                }
            }

            Button(role: .destructive) {
                guard let client = app.client else { return }
                Task { await viewModel.remove(client: client, ids: [memory.id]) }
            } label: {
                Label(String(localized: "删除"), systemImage: "trash")
            }
        }
    }

    private func scopeLabel(_ scope: String?) -> String {
        guard let scope, !scope.isEmpty, scope != "global" else {
            return String(localized: "全局")
        }
        if scope.hasPrefix("project:") {
            let key = String(scope.dropFirst("project:".count))
            return viewModel.projects[key]?.name ?? key
        }
        if scope.hasPrefix("agent:") {
            return String(scope.dropFirst("agent:".count))
        }
        return scope
    }

    private func rankNow() {
        guard let client = app.client else { return }
        Task { await viewModel.rank(client: client, query: query, status: status) }
    }

    private func reload() async {
        guard let client = app.client else { return }
        await viewModel.load(client: client)
        await viewModel.loadDistill(client: client)
        await viewModel.loadSemantic(client: client)
    }
}

// MARK: - 新建 / 编辑

private struct MemoryEditSheet: View {
    let memory: MemoryDTO?
    let onSave: (String, String, String, String, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var why = ""
    @State private var tags = ""
    @State private var kind = MemoryKind.fact.rawValue
    @State private var scope = "global"
    @State private var working = false
    @State private var primed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "要记住的事"), text: $text, axis: .vertical)
                        .lineLimit(3...8)
                } footer: {
                    Text(String(localized: "写成一句完整的话，Agent 检索时更容易命中。"))
                }

                Section(String(localized: "为什么")) {
                    TextField(String(localized: "可选：这条记忆的来由"), text: $why, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(String(localized: "分类")) {
                    Picker(String(localized: "种类"), selection: $kind) {
                        ForEach(MemoryKind.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                    }
                    TextField(String(localized: "标签，逗号分隔"), text: $tags)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(String(localized: "范围（global 或 project:名称）"), text: $scope)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .scrollContentBackground(.hidden)
            .background(MagpieAuroraBackground())
            .navigationTitle(memory == nil ? String(localized: "新建记忆") : String(localized: "编辑记忆"))
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
                    .disabled(working || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard !primed else { return }
                primed = true
                guard let memory else { return }
                text = memory.text ?? ""
                why = memory.why ?? ""
                tags = (memory.tags ?? []).joined(separator: ", ")
                kind = memory.kind ?? MemoryKind.fact.rawValue
                scope = memory.scope ?? "global"
            }
        }
    }

    private func save() {
        working = true
        let body = (
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            why.trimmingCharacters(in: .whitespacesAndNewlines),
            tags,
            kind,
            scope.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            let ok = await onSave(body.0, body.1, body.2, body.3, body.4)
            working = false
            if ok { dismiss() }
        }
    }
}
