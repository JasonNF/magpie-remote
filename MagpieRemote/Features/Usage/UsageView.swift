import SwiftUI
import Charts
import UIKit

/// Usage：对齐官方 Web 的分页结构 —— 总览、请求账本、会话、上下文。
/// 统计、账本、热力图、上下文全部来自 `/api/usage*`、`/api/sessions`、`/api/context`。
struct UsageView: View {
    @Environment(AppModel.self) private var app
    @State private var viewModel = UsageViewModel()
    @State private var isCheckingIn = false
    @State private var overviewSort = "tokens"
    @State private var heatMetric = "calls"
    @State private var selectedRequest: UsageLedgerRowDTO?
    @State private var showingClearConfirm = false
    @State private var exportPath: String?
    @State private var actionError: String?

    private let periods: [(String, String)] = [
        ("today", "今天"),
        ("last:24h", "24 小时"),
        ("7d", "7 天"),
        ("30d", "30 天"),
        ("all", "全部")
    ]

    private var loadKey: String {
        "\(viewModel.tab.rawValue)|\(viewModel.period)"
    }

    var body: some View {
        MagpieNavigationContainer {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    tabBar

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    switch viewModel.tab {
                    case .overview:
                        overviewSection
                    case .requests:
                        requestsSection
                    case .sessions:
                        sessionsSection
                    case .context:
                        contextSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "Usage"))
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            if let client = app.client {
                                Task { await viewModel.reloadForTab(client: client) }
                            }
                        } label: {
                            Label(String(localized: "刷新"), systemImage: "arrow.clockwise")
                        }

                        Button {
                            exportLedger()
                        } label: {
                            Label(String(localized: "导出账本 CSV 到服务器…"), systemImage: "tablecells")
                        }

                        Button {
                            copyLedgerCSV()
                        } label: {
                            Label(String(localized: "复制账本 CSV"), systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingClearConfirm = true
                        } label: {
                            Label(String(localized: "清除用量统计…"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewModel.isLoading || viewModel.isLedgerLoading || viewModel.isOperating)
                }
            }
            .confirmationDialog(
                String(localized: "清除全部用量统计？"),
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "清除"), role: .destructive) {
                    clearUsage()
                }
                Button(String(localized: "取消"), role: .cancel) {}
            } message: {
                Text(String(localized: "此前的调用将不再计入用量页与图表；账本文件仍保留在服务器上，Key 的预算仍按它们计数。"))
            }
            .alert(
                String(localized: "已导出"),
                isPresented: Binding(
                    get: { exportPath != nil },
                    set: { if !$0 { exportPath = nil } }
                )
            ) {
                Button(String(localized: "复制路径")) {
                    if let path = exportPath { UIPasteboard.general.string = path }
                    exportPath = nil
                }
                Button(String(localized: "完成"), role: .cancel) { exportPath = nil }
            } message: {
                Text(exportPath ?? "")
            }
            .alert(
                String(localized: "操作失败"),
                isPresented: Binding(
                    get: { actionError != nil },
                    set: { if !$0 { actionError = nil } }
                )
            ) {
                Button(String(localized: "好"), role: .cancel) { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
            .task(id: loadKey) {
                guard let client = app.client else { return }
                await viewModel.reloadForTab(client: client)
                if viewModel.tab == .requests {
                    viewModel.startTraffic(client: client)
                } else {
                    viewModel.stopTraffic()
                }
            }
            .onDisappear {
                viewModel.stopTraffic()
            }
            .refreshable {
                if let client = app.client {
                    await viewModel.reloadForTab(client: client)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.usage == nil && viewModel.tab == .overview {
                    ProgressView(String(localized: "正在统计用量…"))
                }
            }
            .sheet(item: $selectedRequest) { row in
                UsageRequestDetailSheet(row: row)
            }
        }
    }

    // MARK: - 工具动作
    private func clearUsage() {
        guard let client = app.client else { return }
        Task {
            if await viewModel.clearUsage(client: client) {
                MagpieHaptics.success()
            } else {
                actionError = viewModel.errorMessage ?? String(localized: "清除失败")
            }
        }
    }

    private func exportLedger() {
        guard let client = app.client else { return }
        Task {
            if let result = await viewModel.exportLedger(client: client) {
                exportPath = result.path ?? String(localized: "已导出 \(result.rows ?? 0) 行")
                MagpieHaptics.success()
            } else {
                actionError = viewModel.errorMessage ?? String(localized: "导出失败")
            }
        }
    }

    private func copyLedgerCSV() {
        guard let client = app.client else { return }
        Task {
            if let csv = await viewModel.fetchLedgerCSV(client: client), !csv.isEmpty {
                UIPasteboard.general.string = csv
                MagpieHaptics.success()
            } else {
                actionError = viewModel.errorMessage ?? String(localized: "读取 CSV 失败")
            }
        }
    }

    // MARK: - 头部
    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "用量与配额"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(viewModel.periodTitle + String(localized: " · 网关调用"))
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Spacer()

                if let usage = viewModel.usage {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(usage.formattedCost)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(MagpieTheme.green)
                        Text(String(localized: "估算费用"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(periods, id: \.0) { item in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                viewModel.period = item.0
                            }
                            MagpieHaptics.light()
                        } label: {
                            Text(item.1)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background {
                                    if viewModel.period == item.0 {
                                        LinearGradient(
                                            colors: [MagpieTheme.accent, MagpieTheme.accent.opacity(0.72)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    } else {
                                        MagpieTheme.card.opacity(0.65)
                                    }
                                }
                                .foregroundStyle(viewModel.period == item.0 ? .white : MagpieTheme.textSecondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        viewModel.period == item.0
                                            ? Color.white.opacity(0.2)
                                            : MagpieTheme.borderSubtle,
                                        lineWidth: 0.8
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .magpieCard()
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UsageViewModel.UsageTab.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            viewModel.tab = item
                        }
                        MagpieHaptics.light()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if viewModel.tab == item {
                                LinearGradient(
                                    colors: [MagpieTheme.accent, MagpieTheme.accent.opacity(0.72)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                MagpieTheme.card.opacity(0.6)
                            }
                        }
                        .foregroundStyle(viewModel.tab == item ? .white : MagpieTheme.textSecondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                viewModel.tab == item
                                    ? Color.white.opacity(0.2)
                                    : MagpieTheme.borderSubtle,
                                lineWidth: 0.8
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: - 总览
    @ViewBuilder
    private var overviewSection: some View {
        if let usage = viewModel.usage {
            metricsGrid(usage)
            tokenChartCard(usage)

            if let groups = usage.agents, !groups.isEmpty {
                groupCard(
                    String(localized: "Agents"),
                    icon: "terminal.fill",
                    tint: MagpieTheme.accent,
                    groups: groups
                )
            }
            if let groups = usage.models, !groups.isEmpty {
                groupCard(
                    String(localized: "Models"),
                    icon: "cpu.fill",
                    tint: MagpieTheme.purple,
                    groups: groups
                )
            }
            if let groups = usage.accounts, !groups.isEmpty {
                groupCard(
                    String(localized: "账号"),
                    icon: "person.crop.circle.fill",
                    tint: MagpieTheme.cyan,
                    groups: groups
                )
            }
            if let groups = usage.callerKeys, !groups.isEmpty {
                groupCard(
                    String(localized: "Gateway Keys"),
                    icon: "key.fill",
                    tint: MagpieTheme.amber,
                    groups: groups
                )
            }

            checkinCard

            if !viewModel.quotas.isEmpty {
                quotasSection
            }
        } else if viewModel.isLoading {
            ProgressView().padding(.vertical, 40)
        } else {
            emptyState(
                icon: "chart.bar.xaxis",
                title: String(localized: "还没有用量记录"),
                subtitle: String(localized: "当 Agent 通过网关发起请求后，这里会显示费用、Token 与配额。")
            )
        }
    }

    private func metricsGrid(_ usage: UsageDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MagpieSectionLabel(title: viewModel.periodTitle + String(localized: " 总览"))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                MetricCard(
                    title: String(localized: "预估花费"),
                    value: usage.formattedCost,
                    icon: "dollarsign.circle.fill",
                    color: MagpieTheme.green
                )
                MetricCard(
                    title: String(localized: "调用次数"),
                    value: usage.formattedCalls,
                    icon: "arrow.up.arrow.down.circle.fill",
                    color: MagpieTheme.accent
                )
                MetricCard(
                    title: String(localized: "输入 Tokens"),
                    value: UsageDTO.formatTokens(usage.input ?? 0),
                    icon: "arrow.up.circle.fill",
                    color: MagpieTheme.amber
                )
                MetricCard(
                    title: String(localized: "输出 Tokens"),
                    value: UsageDTO.formatTokens(usage.output ?? 0),
                    icon: "arrow.down.circle.fill",
                    color: MagpieTheme.purple
                )
            }
        }
    }

    private func groupCard(
        _ title: String,
        icon: String,
        tint: Color,
        groups: [UsageGroupDTO]
    ) -> some View {
        let sorted = sortedGroups(groups)
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                MagpieSectionLabel(title: title, detail: "\(groups.count)")
                Spacer()
                Menu {
                    Button(String(localized: "按 Tokens")) { overviewSort = "tokens" }
                    Button(String(localized: "按费用")) { overviewSort = "cost" }
                    Button(String(localized: "按调用")) { overviewSort = "calls" }
                    Button(String(localized: "按名称")) { overviewSort = "name" }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(sortTitle)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textMuted)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(sorted.prefix(10).enumerated()), id: \.offset) { item in
                    let index = item.offset
                    let group = item.element
                    HStack(spacing: 10) {
                        MagpieIconView(icon: group.icon ?? group.provider, name: group.displayName, size: 26, cornerRadius: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.displayName)
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .lineLimit(1)
                            if let sub = group.sub, !sub.isEmpty {
                                Text(sub)
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(UsageDTO.formatTokens(group.totalTokens))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            Text("\(group.calls ?? 0) · \(group.formattedCost)")
                                .font(.caption2)
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)

                    if index < min(sorted.count, 10) - 1 {
                        Divider()
                            .background(MagpieTheme.borderSubtle)
                            .padding(.leading, 49)
                    }
                }
            }
            .magpieCard(padding: 0)
        }
    }

    private var sortTitle: String {
        switch overviewSort {
        case "cost": return String(localized: "费用")
        case "calls": return String(localized: "调用")
        case "name": return String(localized: "名称")
        default: return String(localized: "Tokens")
        }
    }

    private func sortedGroups(_ groups: [UsageGroupDTO]) -> [UsageGroupDTO] {
        groups.sorted { a, b in
            switch overviewSort {
            case "cost":
                return (a.cost ?? 0) > (b.cost ?? 0)
            case "calls":
                return (a.calls ?? 0) > (b.calls ?? 0)
            case "name":
                return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
            default:
                return a.totalTokens > b.totalTokens
            }
        }
    }

    private func tokenChartCard(_ usage: UsageDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MagpieSectionLabel(title: String(localized: "Token 构成"))

            VStack(alignment: .leading, spacing: 12) {
                TokenDistributionChart(usage: usage)
                    .frame(height: 130)

                HStack {
                    legendItem(color: MagpieTheme.amber, label: String(localized: "输入"), value: usage.input ?? 0)
                    Spacer()
                    legendItem(color: MagpieTheme.purple, label: String(localized: "输出"), value: usage.output ?? 0)
                    Spacer()
                    legendItem(color: MagpieTheme.cyan, label: String(localized: "缓存读取"), value: usage.cache_read ?? 0)
                    Spacer()
                    legendItem(color: MagpieTheme.textSecondary, label: String(localized: "缓存写入"), value: usage.cache_write ?? 0)
                }
            }
            .magpieCard()
        }
    }

    private func legendItem(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
                Text(UsageDTO.formatTokens(value))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
            }
        }
    }

    // MARK: - 请求账本
    private var requestsSection: some View {
        VStack(spacing: 14) {
            if !viewModel.trafficText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text(viewModel.trafficText)
                        .font(.system(size: 10.5, design: .monospaced))
                    Spacer()
                    Text(String(localized: "实时"))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(MagpieTheme.greenSoft)
                        .foregroundStyle(MagpieTheme.green)
                        .clipShape(Capsule())
                }
                .foregroundStyle(MagpieTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .magpieCard(padding: 10)
            }

            requestFilters
            ledgerKPI
            heatmapCard
            ledgerList
        }
    }

    private var requestFilters: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textMuted)
                TextField(String(localized: "搜索模型、提供方、会话…"), text: $viewModel.ledgerQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { applyFilters() }
                if !viewModel.ledgerQuery.isEmpty {
                    Button {
                        viewModel.ledgerQuery = ""
                        applyFilters()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(MagpieTheme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    filterChip(
                        String(localized: "失败"),
                        active: viewModel.ledgerFailedOnly,
                        tint: MagpieTheme.red
                    ) {
                        viewModel.ledgerFailedOnly.toggle()
                        applyFilters()
                    }

                    Menu {
                        Button(String(localized: "全部提供方")) { viewModel.ledgerProvider = ""; applyFilters() }
                        ForEach(viewModel.ledgerProviders) { provider in
                            Button(provider.displayName) {
                                viewModel.ledgerProvider = provider.id
                                applyFilters()
                            }
                        }
                    } label: {
                        filterMenuLabel(
                            viewModel.ledgerProvider.isEmpty
                                ? String(localized: "提供方")
                                : (viewModel.ledgerProviders.first { $0.id == viewModel.ledgerProvider }?.displayName ?? viewModel.ledgerProvider),
                            active: !viewModel.ledgerProvider.isEmpty
                        )
                    }

                    Menu {
                        Button(String(localized: "全部 Agent")) { viewModel.ledgerAgent = ""; applyFilters() }
                        ForEach(viewModel.ledgerAgents) { agent in
                            Button(agent.displayName) {
                                viewModel.ledgerAgent = agent.id
                                applyFilters()
                            }
                        }
                    } label: {
                        filterMenuLabel(
                            viewModel.ledgerAgent.isEmpty
                                ? String(localized: "Agent")
                                : (viewModel.ledgerAgents.first { $0.id == viewModel.ledgerAgent }?.displayName ?? viewModel.ledgerAgent),
                            active: !viewModel.ledgerAgent.isEmpty
                        )
                    }

                    Spacer(minLength: 0)
                }
            }
            .scrollClipDisabled()
        }
    }

    private func filterChip(_ title: String, active: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(active ? tint.opacity(0.16) : MagpieTheme.pill)
                .foregroundStyle(active ? tint : MagpieTheme.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(active ? tint.opacity(0.25) : MagpieTheme.borderSubtle, lineWidth: 0.7)
                )
        }
        .buttonStyle(.plain)
    }

    private func filterMenuLabel(_ title: String, active: Bool) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(active ? MagpieTheme.accentSoft : MagpieTheme.pill)
        .foregroundStyle(active ? MagpieTheme.accent : MagpieTheme.textSecondary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(active ? MagpieTheme.accent.opacity(0.25) : MagpieTheme.borderSubtle, lineWidth: 0.7)
        )
    }

    private func applyFilters() {
        guard let client = app.client else { return }
        Task {
            await viewModel.loadLedger(client: client, reset: true)
            await viewModel.loadHeatmap(client: client)
        }
    }

    private var ledgerKPI: some View {
        let ledger = viewModel.ledger
        let calls = ledger?.calls ?? viewModel.usage?.calls ?? 0
        let tokens = (ledger?.input ?? 0) + (ledger?.output ?? 0)
        let cost = ledger?.cost ?? viewModel.usage?.cost
        return HStack(spacing: 0) {
            kpi(String(localized: "请求"), UsageDTO.formatTokens(calls), tint: MagpieTheme.accent)
            kpiDivider
            kpi(String(localized: "Tokens"), UsageDTO.formatTokens(tokens), tint: MagpieTheme.purple)
            kpiDivider
            kpi(String(localized: "费用"), cost.map { String(format: "$%.2f", $0) } ?? "—", tint: MagpieTheme.green)
        }
        .magpieCard(padding: 12)
    }

    private func kpi(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            MagpieGradientNumber(text: value, tint: tint, size: 18)
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(MagpieTheme.borderSubtle)
            .frame(width: 1, height: 24)
    }

    // MARK: - 热力图
    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MagpieSectionLabel(
                    title: String(localized: "用量热力图"),
                    detail: String(localized: "最近 53 周")
                )
                Spacer()
                Picker("", selection: $heatMetric) {
                    Text(String(localized: "请求")).tag("calls")
                    Text(String(localized: "Tokens")).tag("tokens")
                    Text(String(localized: "费用")).tag("cost")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.caption2)
            }

            if viewModel.heatmap == nil {
                if viewModel.isHeatmapLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 16)
                } else {
                    Text(String(localized: "热力图需要先加载请求数据。"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(heatWeeks.enumerated()), id: \.offset) { item in
                            VStack(spacing: 3) {
                                ForEach(item.element) { cell in
                                    heatCell(cell)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()

                HStack(spacing: 5) {
                    Text(String(localized: "少"))
                    ForEach([0.10, 0.3, 0.55, 0.8, 1.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(MagpieTheme.accent.opacity(level))
                            .frame(width: 10, height: 10)
                    }
                    Text(String(localized: "多"))
                    Spacer()
                    Text(heatMetricTitle)
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
            }
        }
        .magpieCard()
    }

    private var heatMetricTitle: String {
        switch heatMetric {
        case "tokens": return String(localized: "Token")
        case "cost": return String(localized: "费用")
        default: return String(localized: "请求")
        }
    }

    private struct HeatCell: Identifiable {
        let id: Int
        let date: String
        let day: UsageHeatDayDTO?
    }

    private var heatWeeks: [[HeatCell]] {
        guard let heatmap = viewModel.heatmap,
              let from = heatmap.from, let to = heatmap.to else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        guard var day = formatter.date(from: from),
              let end = formatter.date(from: to) else { return [] }

        let byDate = (heatmap.days ?? []).reduce(into: [String: UsageHeatDayDTO]()) { partial, day in
            partial[day.date] = day
        }
        var cells: [HeatCell] = []
        var index = 0
        let calendar = Calendar.current
        while day <= end {
            let key = formatter.string(from: day)
            cells.append(HeatCell(id: index, date: key, day: byDate[key]))
            index += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }
    }

    private var heatMax: Double {
        let days = viewModel.heatmap?.days ?? []
        let values = days.map { heatValue($0) }
        return max(values.max() ?? 0, 1)
    }

    private func heatValue(_ day: UsageHeatDayDTO?) -> Double {
        guard let day else { return 0 }
        switch heatMetric {
        case "tokens": return Double(day.tokens ?? 0)
        case "cost": return day.cost ?? 0
        default: return Double(day.calls ?? 0)
        }
    }

    private func heatCell(_ cell: HeatCell) -> some View {
        let value = heatValue(cell.day)
        let ratio = min(max(value / heatMax, 0), 1)
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(value <= 0 ? MagpieTheme.pill : MagpieTheme.accent.opacity(0.14 + 0.86 * ratio))
            .frame(width: 10, height: 10)
            .help(heatHelp(cell, value: value))
    }

    private func heatHelp(_ cell: HeatCell, value: Double) -> String {
        let calls = cell.day?.calls ?? 0
        let tokens = cell.day?.tokens ?? 0
        let cost = cell.day?.cost
        return "\(cell.date)\n\(calls) 请求 · \(UsageDTO.formatTokens(tokens)) tokens" +
            (cost.map { String(format: " · $%.2f", $0) } ?? "")
    }

    // MARK: - 账本列表
    private var ledgerList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MagpieSectionLabel(
                    title: String(localized: "请求"),
                    detail: viewModel.ledgerTotal > 0 ? "\(viewModel.ledgerTotal)" : nil
                )
                Spacer()
                if viewModel.isLedgerLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if viewModel.ledgerRows.isEmpty {
                if viewModel.isLedgerLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                } else {
                    emptyState(
                        icon: "list.bullet.rectangle",
                        title: String(localized: "没有匹配的请求"),
                        subtitle: String(localized: "调整时间范围或筛选条件后再试。")
                    )
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.ledgerRows.enumerated()), id: \.element.id) { item in
                        let index = item.offset
                        let row = item.element
                        Button {
                            selectedRequest = row
                        } label: {
                            ledgerRow(row)
                        }
                        .buttonStyle(.plain)

                        if index < viewModel.ledgerRows.count - 1 {
                            Divider()
                                .background(MagpieTheme.borderSubtle)
                                .padding(.leading, 48)
                        }
                    }
                }
                .magpieCard(padding: 0)

                if viewModel.ledgerHasMore {
                    Button {
                        if let client = app.client {
                            Task { await viewModel.loadLedger(client: client, reset: false) }
                        }
                    } label: {
                        HStack {
                            if viewModel.isLedgerLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text(String(localized: "加载更多"))
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(MagpieTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLedgerLoading)
                }
            }
        }
    }

    private func ledgerRow(_ row: UsageLedgerRowDTO) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(row.isError ? MagpieTheme.red : MagpieTheme.green)
                .frame(width: 6, height: 6)

            MagpieIconView(icon: row.icon ?? row.agent, name: row.displayAgent, size: 26, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.model ?? String(localized: "未知模型"))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(row.displayAgent)
                    Text("·")
                    Text(row.displayProvider)
                }
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(UsageDTO.formatTokens(row.totalTokens))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textSecondary)
                Text(row.formattedCost)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.green)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    // MARK: - 会话
    private var sessionsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                kpi(String(localized: "会话"), "\(viewModel.sessions.count)", tint: MagpieTheme.accent)
                kpiDivider
                kpi(String(localized: "Tokens"), UsageDTO.formatTokens(viewModel.sessionTokenTotal), tint: MagpieTheme.purple)
                kpiDivider
                kpi(String(localized: "费用"), String(format: "$%.2f", viewModel.sessionCostTotal), tint: MagpieTheme.green)
            }
            .magpieCard(padding: 12)

            if viewModel.sessions.isEmpty {
                if viewModel.isSessionsLoading {
                    ProgressView().padding(.vertical, 30)
                } else {
                    emptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: String(localized: "还没有会话记录"),
                        subtitle: String(localized: "Agent 的历史会话会在这里按最新顺序显示。")
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    MagpieSectionLabel(
                        title: String(localized: "最新会话"),
                        detail: String(localized: "完整管理在 Sessions 页")
                    )
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.sessions.prefix(20)) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: SessionDTO) -> some View {
        HStack(spacing: 10) {
            MagpieIconView(icon: session.agent, name: session.displayAgent, size: 30, cornerRadius: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(session.displayAgent)
                    if let last = session.last {
                        Text("·")
                        Text(String(last.prefix(10)))
                    }
                }
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(session.formattedTokens)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textSecondary)
                Text(session.formattedCost)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.green)
            }
        }
        .magpieCard(padding: 11)
    }

    // MARK: - 上下文
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let agents = viewModel.context?.agents, !agents.isEmpty {
                MagpieSectionLabel(
                    title: String(localized: "上下文窗口"),
                    detail: String(localized: "最近 30 天")
                )
                ForEach(agents.sorted { ($0.score ?? 0) > ($1.score ?? 0) }) { agent in
                    contextCard(agent)
                }
            } else if viewModel.isContextLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                emptyState(
                    icon: "rectangle.split.3x1",
                    title: String(localized: "还没有上下文数据"),
                    subtitle: String(localized: "网关记录到带 prompt 的请求后，这里会显示上下文占用、缓存命中与增长趋势。")
                )
            }

            if let tune = viewModel.tune, !(tune.agents ?? []).isEmpty {
                tuneSection(tune)
            }
        }
    }

    // MARK: - 上下文优化建议
    private func tuneSection(_ tune: TuneStateDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MagpieSectionLabel(
                title: "Tuned for you",
                detail: String(localized: "按最近 \(tune.days ?? 30) 天你自己的调用推算")
            )

            ForEach(tune.agents ?? []) { agent in
                if let advice = agent.advice, !advice.isEmpty {
                    tuneAgentCard(agent, advice: advice)
                }
            }
        }
    }

    private func tuneAgentCard(_ agent: TuneAgentDTO, advice: [TuneAdviceDTO]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MagpieIconView(icon: agent.agent, name: agent.displayName, size: 30, cornerRadius: 7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(String(localized: "\(agent.calls ?? 0) 次调用参与推算"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            ForEach(advice) { item in
                Divider().background(MagpieTheme.borderSubtle).padding(.leading, 52)
                tuneAdviceRow(agent: agent.agent, advice: item)
            }
        }
        .magpieCard(padding: 0)
    }

    private func tuneAdviceRow(agent: String, advice: TuneAdviceDTO) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MagpieTheme.purple.opacity(0.13))
                    .frame(width: 30, height: 30)
                Image(systemName: advice.icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MagpieTheme.purple)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(advice.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    if let model = advice.model, !model.isEmpty {
                        MagpieStatusChip(text: model, color: MagpieTheme.accent)
                    }
                    if advice.inUse {
                        MagpieStatusChip(text: String(localized: "已采用"), color: MagpieTheme.green)
                    }
                }

                if let subtitle = advice.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                if let current = advice.currentValue, !current.isEmpty {
                    Text(String(localized: "当前：\(current)") + (advice.proposedValue.map { String(localized: " → 建议：\($0)") } ?? ""))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textSecondary)
                }
            }

            Spacer(minLength: 6)

            if advice.inUse {
                Button(String(localized: "撤销")) {
                    runTune(agent: agent, advice: advice, undo: true)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(MagpieTheme.red)
            } else if advice.proposedValue != nil {
                Button(String(localized: "采用")) {
                    runTune(agent: agent, advice: advice, undo: false)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(MagpieTheme.accent)
            } else if advice.few == true {
                Text(String(localized: "调用太少"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func runTune(agent: String, advice: TuneAdviceDTO, undo: Bool) {
        guard let client = app.client else { return }
        Task {
            let ok = undo
                ? await viewModel.undoTune(client: client, agent: agent, advice: advice)
                : await viewModel.applyTune(client: client, agent: agent, advice: advice)
            if !ok {
                actionError = viewModel.errorMessage ?? String(localized: "操作失败")
            }
        }
    }

    private func contextCard(_ agent: UsageContextAgentDTO) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                MagpieIconView(icon: agent.agent, name: agent.agent, size: 34, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.agent)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(String(localized: "\(agent.requests ?? 0) 个请求 · \(agent.sessions ?? 0) 个会话"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    MagpieGradientNumber(
                        text: "\(agent.score ?? 0)",
                        tint: scoreColor(agent.score ?? 0),
                        size: 22
                    )
                    Text(String(localized: "上下文评分"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }

            ProgressView(value: Double(min(max(agent.score ?? 0, 0), 100)), total: 100)
                .tint(scoreColor(agent.score ?? 0))

            HStack(spacing: 0) {
                contextMetric(String(localized: "中位上下文"), UsageDTO.formatTokens(agent.median ?? 0))
                contextDivider
                contextMetric(String(localized: "P90"), UsageDTO.formatTokens(agent.p90 ?? 0))
                contextDivider
                contextMetric(String(localized: "缓存命中"), String(format: "%.0f%%", (agent.cache ?? 0) * 100))
                contextDivider
                contextMetric(String(localized: "增长"), UsageDTO.formatTokens(agent.growth ?? 0))
            }

            if let tags = agent.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(tags) { tag in
                            MagpieStatusChip(
                                text: tag.key,
                                color: tagColor(tag.tone),
                                icon: "circle.fill"
                            )
                        }
                    }
                }
                .scrollClipDisabled()
            }

            if let models = agent.models, !models.isEmpty {
                Text(models.joined(separator: " · "))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .magpieCard()
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return MagpieTheme.green }
        if score >= 60 { return MagpieTheme.accent }
        return MagpieTheme.amber
    }

    private func tagColor(_ tone: String?) -> Color {
        switch tone {
        case "good": return MagpieTheme.green
        case "warn": return MagpieTheme.amber
        default: return MagpieTheme.accent
        }
    }

    private func contextMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(MagpieTheme.textPrimary)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var contextDivider: some View {
        Rectangle()
            .fill(MagpieTheme.borderSubtle)
            .frame(width: 1, height: 22)
    }

    // MARK: - 配额与签到
    private var checkinCard: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(MagpieTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "每日签到额度"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Text(String(localized: "一键完成 WorkBuddy、Trae、Qoder 等账号签到"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }

            Spacer()

            Button {
                performDailyCheckins()
            } label: {
                if isCheckingIn {
                    ProgressView().controlSize(.small)
                } else {
                    Text(String(localized: "一键签到"))
                }
            }
            .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.accent))
            .disabled(isCheckingIn)
        }
        .magpieCard()
    }

    private var quotasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MagpieSectionLabel(title: String(localized: "服务商配额池"))

            LazyVStack(spacing: 10) {
                ForEach(viewModel.quotas) { quota in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MagpieIconView(icon: quota.icon ?? quota.provider, name: quota.name, size: 28, cornerRadius: 6)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(quota.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Text(quota.provider)
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }

                            Spacer()

                            if let balance = quota.balance, !balance.isEmpty {
                                Text(balance)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(MagpieTheme.green)
                            }

                            Button {
                                guard let client = app.client else { return }
                                Task { await viewModel.refreshQuota(client: client, provider: quota.provider) }
                            } label: {
                                if viewModel.isRefreshingQuota {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(MagpieTheme.textMuted)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isRefreshingQuota)
                            .accessibilityLabel(String(localized: "刷新这张配额卡"))
                        }

                        if let windows = quota.windows, !windows.isEmpty {
                            Divider().background(MagpieTheme.borderSubtle)

                            ForEach(windows) { win in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(win.name)
                                            .font(.caption)
                                            .foregroundStyle(MagpieTheme.textSecondary)
                                        Spacer()
                                        Text(String(format: "%.1f%%", win.percentUsed))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(win.percentUsed > 80 ? MagpieTheme.red : MagpieTheme.accent)
                                    }

                                    ProgressView(value: min(win.percentUsed, 100.0), total: 100.0)
                                        .tint(win.percentUsed > 80 ? MagpieTheme.red : MagpieTheme.accent)
                                }
                            }
                        }
                    }
                    .magpieCard()
                }
            }
        }
    }

    private func performDailyCheckins() {
        guard let client = app.client else { return }
        isCheckingIn = true
        Task {
            defer { isCheckingIn = false }
            _ = try? await client.sendData(Endpoint.post("/api/usage/workbuddy-checkin"))
            _ = try? await client.sendData(Endpoint.post("/api/usage/trae-checkin"))
            _ = try? await client.sendData(Endpoint.post("/api/usage/qoder-checkin"))
            _ = try? await client.sendData(Endpoint.post("/api/usage/minimax-checkin"))
            await viewModel.load(client: client)
        }
    }

    // MARK: - 通用
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(MagpieTheme.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .magpieCard(padding: 12)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(MagpieTheme.textMuted.opacity(0.65))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MagpieTheme.textPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .magpieCard()
    }
}

// MARK: - 指标卡
private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            MagpieGradientNumber(text: value, tint: color, size: 22)
            Text(title)
                .font(.caption)
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .magpieCard(padding: 14, cornerRadius: 18)
    }
}

// MARK: - Token 构成图
private struct TokenSlice: Identifiable {
    let category: String
    let amount: Int
    let color: Color
    var id: String { category }
}

private struct TokenDistributionChart: View {
    let usage: UsageDTO

    private var slices: [TokenSlice] {
        [
            TokenSlice(category: "输入", amount: max(usage.input ?? 0, 1), color: MagpieTheme.amber),
            TokenSlice(category: "输出", amount: max(usage.output ?? 0, 1), color: MagpieTheme.purple),
            TokenSlice(category: "缓存", amount: max((usage.cache_read ?? 0) + (usage.cache_write ?? 0), 1), color: MagpieTheme.cyan)
        ]
    }

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Tokens", slice.amount),
                innerRadius: .ratio(0.68),
                angularInset: 2.0
            )
            .foregroundStyle(slice.color)
            .cornerRadius(4)
        }
    }
}

// MARK: - 请求详情
private struct UsageRequestDetailSheet: View {
    let row: UsageLedgerRowDTO
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 9) {
                            Circle()
                                .fill(row.isError ? MagpieTheme.red : MagpieTheme.green)
                                .frame(width: 8, height: 8)
                            Text(row.model ?? String(localized: "未知模型"))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let status = row.status {
                                Text("HTTP \(status)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(row.isError ? MagpieTheme.red : MagpieTheme.green)
                            }
                        }

                        if let error = row.error, !error.isEmpty {
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(MagpieTheme.red)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 0) {
                            metric(String(localized: "输入"), UsageDTO.formatTokens(row.input ?? 0))
                            divider
                            metric(String(localized: "输出"), UsageDTO.formatTokens(row.output ?? 0))
                            divider
                            metric(String(localized: "缓存"), UsageDTO.formatTokens((row.cacheRead ?? 0) + (row.cacheWrite ?? 0)))
                            divider
                            metric(String(localized: "费用"), row.formattedCost)
                        }
                    }
                    .magpieCard()

                    VStack(alignment: .leading, spacing: 9) {
                        MagpieSectionLabel(title: String(localized: "请求"))
                        info(String(localized: "Agent"), row.displayAgent)
                        info(String(localized: "提供方"), row.displayProvider)
                        info(String(localized: "模型"), row.model)
                        if let requested = row.requested, !requested.isEmpty, requested != row.model {
                            info(String(localized: "请求的模型"), requested)
                        }
                        info(String(localized: "会话"), row.session)
                        info(String(localized: "调用 Key"), row.callerKeyLabel ?? row.callerKeyId)
                        info(String(localized: "耗时"), row.millis.map { "\($0)ms" })
                        info(String(localized: "时间"), row.time)
                        info(String(localized: "来源"), row.source)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .magpieCard()
                }
                .padding(16)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "请求详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(MagpieTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(MagpieTheme.borderSubtle)
            .frame(width: 1, height: 24)
    }

    private func info(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(MagpieTheme.textMuted)
            Spacer()
            Text(value?.isEmpty == false ? value! : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MagpieTheme.textPrimary)
                .lineLimit(1)
        }
    }
}
