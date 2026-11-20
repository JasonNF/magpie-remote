import SwiftUI

// MARK: - Web 原版 Routing 舞台 (.rt) 的 SwiftUI 复刻
//
// 原版结构：顶部说明（.rt-what / .rt-mode）→ 舞台（Agent 列、magpie 枢纽、
// 候选账号列、虚线流向）→ 底部解说与 KPI（.rt-cap / .rt-stats）。
// 窄屏按原版 max560 布局：Agent 与 magpie 并排，账号列表在下方。

struct RoutingStageCard: View {
    let route: GatewayRouteDTO?
    let routes: [GatewayRouteDTO]
    let requestsCount: Int
    let reroutedCount: Int
    let errorCount: Int
    let isHistory: Bool
    let isReceivingTrace: Bool
    let masked: Bool
    let activeURL: URL?
    let filterStatus: RouteFilterStatus
    let onFilter: (RouteFilterStatus) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchors: [String: CGRect] = [:]
    @State private var accountsExpanded = true
    @State private var appeared = false

    private var accounts: [GatewayWeighedDTO] { route?.order ?? [] }
    private var isLive: Bool { route?.isPending == true && !isHistory && isReceivingTrace }
    private var isResponding: Bool { (route?.contentAt ?? 0) > 0 }

    private var stageAgents: [RoutingStageAgent] {
        var seen = Set<String>()
        var out: [RoutingStageAgent] = []
        if let route, let agent = route.agent, !agent.isEmpty {
            seen.insert(agent)
            out.append(RoutingStageAgent(id: agent, model: route.model))
        }
        if isLive {
            for item in routes where item.isPending {
                guard let agent = item.agent, !agent.isEmpty, seen.insert(agent).inserted else { continue }
                out.append(RoutingStageAgent(id: agent, model: item.model))
                if out.count >= 3 { break }
            }
        }
        return out
    }

    private var accent: Color {
        RoutingStagePalette.color(for: stageAgents.first?.id ?? "magpie")
    }

    private var agentWireColors: [String: Color] {
        var out: [String: Color] = [:]
        for (index, agent) in stageAgents.enumerated() {
            out["agent-\(index)"] = RoutingStagePalette.color(for: agent.id)
        }
        return out
    }

    /// 每帧都重新构造飞行路径会拖慢主线程；只在锚点或数据变化时计算一次。
    private var stageFlights: [RoutingFlight] {
        RoutingStageFliers.makeFlights(
            anchors: anchors,
            accountIndex: route?.focusedAccountIndex,
            responding: isResponding,
            accent: accent
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                headline
                if route != nil || (isReceivingTrace && !isHistory) {
                    Text(modeText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(MagpieTheme.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            stageLayout

            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MagpieTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MagpieTheme.border, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 6)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true }
        }
    }

    // MARK: - 顶部说明

    private var headline: Text {
        let name = route?.group?.displayName
            ?? accounts.first(where: { $0.fallback != true })?.name
            ?? route?.provider
            ?? route?.agent
            ?? "magpie"
        return Text(name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(MagpieTheme.textPrimary)
            + Text(headlineTail)
            .font(.system(size: 13))
            .foregroundColor(MagpieTheme.textMuted)
    }

    private var headlineTail: String {
        guard let route else {
            return isReceivingTrace && !isHistory ? String(localized: " · 等待下一次请求") : ""
        }
        var parts: [String] = []
        if route.group != nil { parts.append(String(localized: "路由组")) }
        let onCount = route.group?.members?.count ?? accounts.count
        if accounts.isEmpty {
            if route.isPending { parts.append(String(localized: "正在读取请求")) }
        } else {
            parts.append(onCount == 1
                ? String(localized: "启用 1 个")
                : String(localized: "启用 \(onCount) 个"))
        }
        if stageAgents.count > 1 {
            parts.append(String(localized: "\(stageAgents.count) 个 Agent 同时在发"))
        }
        return parts.isEmpty ? "" : " · " + parts.joined(separator: " · ")
    }

    private var strategyRaw: String {
        if let groupRouting = route?.group?.routing, !groupRouting.isEmpty {
            return groupRouting
        }
        if let accountRouting = accounts.first(where: { $0.fallback != true })?.routing, !accountRouting.isEmpty {
            return accountRouting
        }
        if let accountRouting = accounts.first?.routing, !accountRouting.isEmpty {
            return accountRouting
        }
        return "smart"
    }

    private var modeText: String {
        guard let route else {
            return String(localized: "实时读取网关的路由记录；下一次请求会在这里显示去向。")
        }
        if accounts.isEmpty {
            return route.isPending
                ? String(localized: "magpie 正在读取请求并决定去向。")
                : String(localized: "这次请求没有可用的账号或 Key。")
        }
        if route.group == nil, accounts.count == 1 {
            return String(localized: "这里只开了一个账号或 Key，路由没有可选的。在供应商的编辑页再开一个，路由方式就在下面的「多账号 / 多 Key」里设置。")
        }
        return RoutingStagePalette.strategyDescription(strategyRaw)
    }

    private var strategyShort: String? {
        RoutingStagePalette.strategyShort(strategyRaw)
    }

    private var hubSubtitle: String {
        let host: String
        if let url = activeURL {
            let name = url.host ?? "127.0.0.1"
            host = url.port.map { "\(name):\($0)" } ?? name
        } else {
            host = "127.0.0.1:3425"
        }
        if !isReceivingTrace { return host }
        if isHistory { return String(localized: "历史记录 · \(host)") }
        return isLive
            ? String(localized: "正在路由 · \(host)")
            : String(localized: "app 正在待命 · \(host)")
    }

    // MARK: - 舞台

    private var agentColumn: some View {
        VStack(spacing: 10) {
            if stageAgents.isEmpty {
                RoutingStageIdleNode(text: String(localized: "等待 Agent"))
            } else {
                ForEach(Array(stageAgents.enumerated()), id: \.element.id) { index, agent in
                    RoutingStageAgentNode(agent: agent, color: RoutingStagePalette.color(for: agent.id))
                        .routingStageAnchor("agent-\(index)")
                }
            }
        }
    }

    private var hubNode: some View {
        RoutingStageHubNode(subtitle: hubSubtitle, chip: strategyShort)
            .routingStageAnchor("hub")
    }

    private var accountsColumn: some View {
        RoutingStageAccountsColumn(
            group: route?.group,
            accounts: accounts,
            expanded: $accountsExpanded,
            masked: masked,
            chosenIndex: route?.focusedAccountIndex,
            isPending: isLive,
            isResponding: isResponding,
            accent: accent
        )
        .routingStageAnchor("accounts")
    }

    @ViewBuilder
    private var stageLayout: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 28) {
                    agentColumn.frame(width: 170)
                    hubNode.frame(width: 190)
                    accountsColumn
                }
                .padding(.vertical, 18)
            } else {
                VStack(spacing: 26) {
                    HStack(alignment: .center, spacing: 28) {
                        agentColumn.frame(maxWidth: .infinity)
                        hubNode.frame(maxWidth: .infinity)
                    }
                    accountsColumn.padding(.leading, 22)
                }
                .padding(.vertical, 16)
            }
        }
        .coordinateSpace(name: "routing-stage")
        .onPreferenceChange(RoutingStageAnchorKey.self) { newAnchors in
            // 布局稳定后 preference 会重复触发；不比较会形成无意义的更新循环。
            guard newAnchors != anchors else { return }
            anchors = newAnchors
        }
        .background(
            RoutingStageWires(
                anchors: anchors,
                colors: agentWireColors,
                accent: accent
            )
            .allowsHitTesting(false)
        )
        .overlay {
            // 没有进行中的请求时不播放飞鸟，避免空闲页面持续重绘。
            if isLive && !reduceMotion {
                RoutingStageFliers(flights: stageFlights)
                    .id(RoutingFlightState(requestID: route?.id, accountIndex: route?.focusedAccountIndex, responding: isResponding))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - 底部解说与 KPI

    private var footer: some View {
        VStack(spacing: 10) {
            Divider().overlay(MagpieTheme.border)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 14) {
                    if route != nil || (isReceivingTrace && !isHistory) { caption }
                    Spacer(minLength: 6)
                    stats
                }
                VStack(alignment: .leading, spacing: 8) {
                    if route != nil || (isReceivingTrace && !isHistory) { caption }
                    HStack {
                        Spacer()
                        stats
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    private var caption: some View {
        Text(RoutingFormat.decisionCaption(for: route))
            .font(.system(size: 12))
            .foregroundStyle(MagpieTheme.textSecondary)
            .lineSpacing(2)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var stats: some View {
        HStack(spacing: 14) {
            stat(String(localized: "请求"), requestsCount, .all, MagpieTheme.textPrimary)
            stat(String(localized: "改写"), reroutedCount, .rerouted, MagpieTheme.textPrimary)
            stat(String(localized: "错误"), errorCount, .errors, errorCount > 0 ? MagpieTheme.red : MagpieTheme.textPrimary)
        }
    }

    private func stat(_ title: String, _ value: Int, _ status: RouteFilterStatus, _ color: Color) -> some View {
        let isSelected = filterStatus == status
        let showChip = isSelected && status != .all
        return Button {
            MagpieHaptics.light()
            onFilter(status)
        } label: {
            VStack(alignment: .trailing, spacing: 0) {
                Text(RoutingStagePalette.count(value))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? color : MagpieTheme.textSecondary)
                Text(title)
                    .font(.system(size: 10, weight: showChip ? .semibold : .regular))
                    .foregroundStyle(showChip ? color : MagpieTheme.textMuted)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            .background {
                if showChip {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.12))
                }
            }
            .overlay {
                if showChip {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(color.opacity(0.35), lineWidth: 0.8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - 舞台数据

struct RoutingStageAgent: Identifiable {
    let id: String
    let model: String?
}

enum RoutingStagePalette {
    // 原版 PALETTE：十二个同一明度的安静颜色，Claude 的陶土色排第一。
    private static let palette: [Color] = [
        Color(hex: "d97757"), Color(hex: "bd8638"), Color(hex: "a59234"),
        Color(hex: "849e4a"), Color(hex: "5aa66c"), Color(hex: "25a98f"),
        Color(hex: "00a6b0"), Color(hex: "2e9fc9"), Color(hex: "5e95d7"),
        Color(hex: "858ad7"), Color(hex: "a47fca"), Color(hex: "bb77b1")
    ]

    private static let known: [String: Int] = [
        "claude": 0, "codex": 9, "gemini": 7, "copilot": 10, "cursor": 5,
        "opencode": 2, "crush": 11, "goose": 3, "pi": 4, "omp": 11,
        "omo": 10, "dsh": 6, "commandcode": 1, "mimocode": 8, "deveco": 7
    ]

    static func color(for id: String) -> Color {
        let key = id.lowercased()
        let index: Int
        if let fixed = known[key] {
            index = fixed
        } else {
            var hash: UInt32 = 0
            for scalar in key.unicodeScalars {
                hash = hash &* 31 &+ scalar.value
            }
            index = Int(hash % UInt32(palette.count))
        }
        return palette[index % palette.count]
    }

    static func strategyShort(_ raw: String?) -> String? {
        switch raw {
        case "smart": return String(localized: "智能")
        case "order": return String(localized: "按序")
        case "rotate": return String(localized: "轮询")
        case "usage": return String(localized: "少用")
        case "pace": return String(localized: "节奏")
        case "weight": return String(localized: "加权")
        case "fast", "fastest", "speed": return String(localized: "测速")
        default: return raw?.isEmpty == false ? raw : nil
        }
    }

    static func strategyDescription(_ raw: String?) -> String {
        switch raw {
        case "smart":
            return String(localized: "智能：有余量的账号中额度最先重置的排第一，以免剩余额度在重置时作废。")
        case "order":
            return String(localized: "按序：按账号列表的顺序依次尝试，前面的账号不能应答时才往后走。")
        case "rotate":
            return String(localized: "轮询：在可用账号之间轮流分配请求，让每个账号的用量保持均衡。")
        case "usage":
            return String(localized: "少用优先：优先选择当前用量最低、余量最多的账号。")
        case "pace":
            return String(localized: "节奏优先：选择剩余额度与重置时间最匹配的账号，尽量不让额度闲置或提前用尽。")
        case "weight":
            return String(localized: "加权：按账号权重分配请求，权重高的账号承担更多调用。")
        case "fast", "fastest", "speed":
            return String(localized: "测速优先：优先选择响应最快的账号。")
        default:
            return String(localized: "网关正在实时权衡账号，选择这次请求的去向。")
        }
    }

    static func count(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    @MainActor private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    @MainActor private static let isoBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    @MainActor private static let resetFallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    static func amount(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number)
    }

    @MainActor
    static func reset(_ raw: String) -> String? {
        guard let date = isoFractional.date(from: raw) ?? isoBasic.date(from: raw) else {
            return nil
        }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day
        if let days, days >= 0, days <= 30 {
            return days == 0 ? String(localized: "今天") : String(localized: "\(days) 天后")
        }
        return resetFallbackFormatter.string(from: date)
    }
}

// MARK: - 舞台节点

private struct RoutingStageIdleNode: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(MagpieTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .background(MagpieTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MagpieTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
    }
}

private struct RoutingStageAgentNode: View {
    let agent: RoutingStageAgent
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            MagpieIconView(icon: agent.id, name: agent.id, size: 26, cornerRadius: 6)
                .padding(.bottom, 3)

            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(agent.id)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .lineLimit(1)
            }

            if let model = agent.model, !model.isEmpty {
                Text(model)
                    .font(.system(size: 11))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MagpieTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MagpieTheme.border, lineWidth: 1)
        )
    }
}

private struct RoutingStageHubNode: View {
    let subtitle: String
    let chip: String?

    var body: some View {
        VStack(spacing: 2) {
            MagpieLogoView(size: 26, showText: false, isAnimated: false)
                .padding(.bottom, 3)

            Text("magpie")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MagpieTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(MagpieTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let chip {
                Text(chip)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(MagpieTheme.card)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                    .background(MagpieTheme.textPrimary, in: Capsule())
                    .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MagpieTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MagpieTheme.textPrimary, lineWidth: 1)
        )
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MagpieTheme.cardSecondary)
        )
    }
}

// MARK: - 候选账号列

private struct RoutingStageAccountsColumn: View {
    let group: GatewayGroupRefDTO?
    let accounts: [GatewayWeighedDTO]
    @Binding var expanded: Bool
    let masked: Bool
    let chosenIndex: Int?
    let isPending: Bool
    let isResponding: Bool
    let accent: Color

    var body: some View {
        VStack(spacing: 7) {
            if accounts.isEmpty {
                Text(String(localized: "等待网关的路由记录"))
                    .font(.system(size: 12))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MagpieTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(MagpieTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            } else {
                if let group {
                    header(group)
                }
                if expanded {
                    ForEach(Array(accounts.enumerated()), id: \.offset) { index, account in
                        RoutingStageAccountRow(
                            account: account,
                            masked: masked,
                            isOn: index == chosenIndex,
                            isLive: isPending && index == chosenIndex,
                            isResponding: isResponding,
                            accent: accent
                        )
                        .routingStageAnchor("account-\(index)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header(_ group: GatewayGroupRefDTO) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
            MagpieHaptics.light()
        } label: {
            HStack(spacing: 7) {
                MagpieIconView(
                    icon: accounts.first?.icon ?? group.id,
                    name: group.displayName,
                    size: 18,
                    cornerRadius: 4
                )

                Text(group.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .lineLimit(1)

                Text(group.ref ?? accounts.first?.model ?? "")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
                    .layoutPriority(-1)

                Spacer(minLength: 4)

                let groupRouting = group.routing ?? ""
                let accountRouting = accounts
                    .first(where: { !($0.routing ?? "").isEmpty })?
                    .routing
                let routing = groupRouting.isEmpty ? (accountRouting ?? "smart") : groupRouting
                if let strategy = RoutingStagePalette.strategyShort(routing) {
                    Text(strategy)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(MagpieTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .overlay(
                            Capsule().stroke(MagpieTheme.border, lineWidth: 1)
                        )
                }

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MagpieTheme.cardSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MagpieTheme.border, style: StrokeStyle(lineWidth: 1, dash: expanded ? [] : [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(expanded ? String(localized: "已展开") : String(localized: "已收起"))
        .accessibilityHint(String(localized: "轻点切换候选账号列表"))
    }
}

private struct RoutingStageAccountRow: View {
    let account: GatewayWeighedDTO
    let masked: Bool
    let isOn: Bool
    let isLive: Bool
    let isResponding: Bool
    let accent: Color

    private var displayName: String {
        RoutingFormat.maskString(account.who ?? account.name ?? account.id, isMasked: masked)
    }

    private var statusText: String {
        if let why = account.why, !why.isEmpty { return why }
        if account.isResting { return account.restReason ?? String(localized: "休息中") }
        if account.aside == true { return String(localized: "本次未参与") }
        var parts: [String] = []
        if let used = account.used {
            if let amount = account.amount, let limit = account.limit {
                let unit = account.unit.map { " \($0)" } ?? ""
                parts.append("\(RoutingStagePalette.amount(amount))/\(RoutingStagePalette.amount(limit))\(unit)")
            }
            parts.append(String(localized: "剩余 \(max(0, 100 - Int(used.rounded())))%"))
            if let due = account.due, let reset = RoutingStagePalette.reset(due) {
                parts.append(String(localized: "\(reset)重置"))
            }
        } else if let balance = account.balance, !balance.isEmpty {
            parts.append(balance)
        }
        if parts.isEmpty { return String(localized: "可用") }
        return parts.joined(separator: " · ")
    }

    private var statusColor: Color {
        if account.isResting { return MagpieTheme.red }
        if account.aside == true { return MagpieTheme.textMuted }
        return MagpieTheme.textMuted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(isOn ? MagpieTheme.textPrimary : Color.clear)
                    .overlay(
                        Circle().stroke(
                            isOn ? MagpieTheme.textPrimary : MagpieTheme.textMuted.opacity(0.7),
                            lineWidth: 1.5
                        )
                    )
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        MagpieIconView(
                            icon: account.icon ?? account.provider,
                            name: account.name ?? account.provider ?? "account",
                            size: 16,
                            cornerRadius: 4
                        )

                        Text(displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MagpieTheme.textPrimary)
                            .lineLimit(1)

                        if let plan = account.plan, !plan.isEmpty {
                            Text(plan)
                                .font(.system(size: 11))
                                .foregroundStyle(MagpieTheme.textMuted)
                                .lineLimit(1)
                        }

                        if let model = account.model, !model.isEmpty {
                            Text(model)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textSecondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(MagpieTheme.cardSecondary)
                                )
                                .lineLimit(1)
                        }

                        if account.fallback == true {
                            Text(String(localized: "备选"))
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(MagpieTheme.textMuted)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .overlay(
                                    Capsule().stroke(MagpieTheme.border, lineWidth: 1)
                                )
                        }
                    }

                    if isLive {
                        Text(isResponding ? String(localized: "回答中…") : String(localized: "调度中"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(accent)
                    } else {
                        Text(statusText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(statusColor)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            if let used = account.used {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MagpieTheme.cardSecondary)
                        Capsule()
                            .fill(isOn ? MagpieTheme.textPrimary : MagpieTheme.textMuted.opacity(0.55))
                            .frame(width: max(geo.size.width * min(max(used / 100, 0), 1), 2))
                    }
                }
                .frame(height: 3)
                .padding(.leading, 18)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MagpieTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isOn ? MagpieTheme.textPrimary : MagpieTheme.border, lineWidth: isOn ? 1 : 0.8)
        )
        .opacity(account.aside == true ? 0.5 : 1)
    }
}

// MARK: - 舞台虚线

struct RoutingStageAnchorKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func routingStageAnchor(_ id: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: RoutingStageAnchorKey.self,
                    value: [id: geo.frame(in: .named("routing-stage"))]
                )
            }
        )
    }
}

private struct RoutingStageWires: View {
    let anchors: [String: CGRect]
    let colors: [String: Color]
    let accent: Color

    var body: some View {
        canvas
    }

    private var canvas: some View {
        Canvas { context, _ in
            guard !anchors.isEmpty else { return }
            let style = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 5])

            let hub = anchors["hub"]
            let accounts = anchors["accounts"]
            let agentKeys = anchors.keys
                .filter { $0.hasPrefix("agent-") }
                .sorted()

            if let hub {
                for key in agentKeys {
                    guard let agent = anchors[key] else { continue }
                    let start = CGPoint(x: agent.maxX, y: agent.midY)
                    let end = CGPoint(x: hub.minX, y: hub.midY)
                    var path = Path()
                    path.move(to: start)
                    path.addCurve(
                        to: end,
                        control1: CGPoint(x: start.x + (end.x - start.x) * 0.45, y: start.y),
                        control2: CGPoint(x: start.x + (end.x - start.x) * 0.55, y: end.y)
                    )
                    context.stroke(path, with: .color(colors[key] ?? accent), style: style)
                }
            }

            guard let hub, let accounts else { return }
            let accountKeys = anchors.keys
                .filter { $0.hasPrefix("account-") }
                .sorted()

            if accounts.minX < hub.midX {
                let laneX = accounts.minX - 10
                let lastY = accountKeys.compactMap { anchors[$0]?.midY }.max() ?? accounts.midY
                var trunk = Path()
                trunk.move(to: CGPoint(x: hub.midX, y: hub.maxY))
                trunk.addCurve(
                    to: CGPoint(x: laneX, y: hub.maxY + 16),
                    control1: CGPoint(x: hub.midX, y: hub.maxY + 10),
                    control2: CGPoint(x: laneX, y: hub.maxY + 6)
                )
                trunk.addLine(to: CGPoint(x: laneX, y: lastY))
                context.stroke(trunk, with: .color(accent.opacity(0.75)), style: style)

                for key in accountKeys {
                    guard let row = anchors[key] else { continue }
                    var stub = Path()
                    stub.move(to: CGPoint(x: laneX, y: row.midY))
                    stub.addLine(to: CGPoint(x: row.minX, y: row.midY))
                    context.stroke(stub, with: .color(accent.opacity(0.75)), style: style)
                }
            } else {
                for key in accountKeys {
                    guard let row = anchors[key] else { continue }
                    let start = CGPoint(x: hub.maxX, y: hub.midY)
                    let end = CGPoint(x: row.minX, y: row.midY)
                    var path = Path()
                    path.move(to: start)
                    path.addCurve(
                        to: end,
                        control1: CGPoint(x: start.x + 20, y: start.y),
                        control2: CGPoint(x: end.x - 20, y: end.y)
                    )
                    context.stroke(path, with: .color(accent.opacity(0.75)), style: style)
                }
            }
        }
    }
}

// MARK: - 飞舞的 magpie（沿虚线往返）

/// 在舞台虚线上飞行的小 magpie logo：出站从 Agent 飞向枢纽，再从枢纽飞向候选账号；
/// 返程从账号飞回枢纽。路径使用与虚线一致的控制点，鸟身随切线轻微倾斜。
private struct RoutingStageFliers: View {
    let flights: [RoutingFlight]

    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    static func makeFlights(
        anchors: [String: CGRect],
        accountIndex: Int?,
        responding: Bool,
        accent: Color
    ) -> [RoutingFlight] {
        guard let hub = anchors["hub"] else { return [] }
        var out: [RoutingFlight] = []

        if let agent = anchors["agent-0"] {
            let start = CGPoint(x: agent.maxX, y: agent.midY)
            let end = CGPoint(x: hub.minX, y: hub.midY)
            let cubic = RoutingCubic(
                p0: start,
                p1: CGPoint(x: start.x + (end.x - start.x) * 0.45, y: start.y),
                p2: CGPoint(x: start.x + (end.x - start.x) * 0.55, y: end.y),
                p3: end
            )
            out.append(
                RoutingFlight(
                    id: "agent",
                    segments: [cubic],
                    color: accent,
                    duration: 1.55,
                    delay: 0,
                    cycle: 2.35,
                    reversed: responding
                )
            )
        }

        if let account = accountIndex.flatMap({ anchors["account-\($0)"] }),
           let accounts = anchors["accounts"] {
            let start = CGPoint(x: hub.midX, y: hub.maxY)
            let laneX = accounts.minX - 10
            let rowEnd = CGPoint(x: account.minX, y: account.midY)
            let segments: [RoutingCubic]

            if accounts.minX < hub.midX {
                let curve = RoutingCubic(
                    p0: start,
                    p1: CGPoint(x: hub.midX, y: hub.maxY + 10),
                    p2: CGPoint(x: laneX, y: hub.maxY + 6),
                    p3: CGPoint(x: laneX, y: hub.maxY + 16)
                )
                segments = [
                    curve,
                    .line(from: curve.p3, to: CGPoint(x: laneX, y: account.midY)),
                    .line(from: CGPoint(x: laneX, y: account.midY), to: rowEnd)
                ]
            } else {
                let start = CGPoint(x: hub.maxX, y: hub.midY)
                segments = [RoutingCubic(
                    p0: start,
                    p1: CGPoint(x: start.x + 20, y: start.y),
                    p2: CGPoint(x: rowEnd.x - 20, y: rowEnd.y),
                    p3: rowEnd
                )]
            }

            out.append(
                RoutingFlight(
                    id: "account",
                    segments: segments,
                    color: responding ? accent.opacity(0.72) : accent,
                    duration: 1.35,
                    delay: 0.55,
                    cycle: 2.9,
                    reversed: responding
                )
            )
        }

        return out
    }

    var body: some View {
        // 限制在 30fps：默认跟随屏幕刷新率（ProMotion 下 120Hz），每帧还带阴影滤镜，发热明显。
        TimelineView(AnimationTimelineSchedule(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)) { timeline in
            let now = max(0, timeline.date.timeIntervalSince(startedAt))
            Canvas { context, _ in
                for flight in flights {
                    guard let pose = flight.pose(at: now), pose.opacity > 0.001 else { continue }
                    let bob = CGFloat(sin(now * 9 + flight.delay * 5) * 1.4)
                    let bank = max(min(pose.angle * 0.22, CGFloat.pi / 10), -CGFloat.pi / 10)
                    let flapProg = (now + flight.delay).truncatingRemainder(dividingBy: 0.42) / 0.42

                    context.drawLayer { layer in
                        layer.opacity = Double(pose.opacity)
                        layer.addFilter(.shadow(color: flight.color.opacity(0.35), radius: 3))
                        layer.translateBy(x: pose.point.x, y: pose.point.y + bob)
                        layer.rotate(by: .radians(bank))
                        if pose.dx < 0 {
                            layer.scaleBy(x: -1, y: 1)
                        }
                        RoutingMagpieBird.draw(
                            in: &layer,
                            color: flight.color,
                            progress: flapProg,
                            isReturn: flight.reversed
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct RoutingFlightState: Hashable {
    let requestID: Int64?
    let accountIndex: Int?
    let responding: Bool
}

private struct RoutingFlight: Identifiable {
    let id: String
    let segments: [RoutingCubic]
    let color: Color
    let duration: TimeInterval
    let delay: TimeInterval
    let cycle: TimeInterval
    let reversed: Bool

    func pose(at now: TimeInterval) -> RoutingFlightPose? {
        let local = ((now + delay).truncatingRemainder(dividingBy: cycle)) / duration
        guard local >= 0, local <= 1 else { return nil }
        let t = reversed ? 1 - local : local
        guard let current = point(at: t) else { return nil }
        let ahead = point(at: min(t + 0.012, 1)) ?? current
        let behind = point(at: max(t - 0.012, 0)) ?? current
        let direction: CGFloat = reversed ? -1 : 1
        let dx = (ahead.x - behind.x) * direction
        let dy = (ahead.y - behind.y) * direction
        let fade = min(min(CGFloat(local) / 0.08, (1 - CGFloat(local)) / 0.08), 1)
        return RoutingFlightPose(
            point: current,
            angle: atan2(dy, dx),
            dx: dx,
            opacity: max(fade, 0)
        )
    }

    private func point(at t: CGFloat) -> CGPoint? {
        guard !segments.isEmpty else { return nil }
        let clamped = min(max(t, 0), 1)
        let scaled = clamped * CGFloat(segments.count)
        let index = min(Int(scaled), segments.count - 1)
        let local = scaled - CGFloat(index)
        return segments[index].point(at: local)
    }
}

private struct RoutingFlightPose {
    let point: CGPoint
    let angle: CGFloat
    let dx: CGFloat
    let opacity: CGFloat
}

private struct RoutingCubic {
    let p0: CGPoint
    let p1: CGPoint
    let p2: CGPoint
    let p3: CGPoint

    static func line(from: CGPoint, to: CGPoint) -> RoutingCubic {
        RoutingCubic(
            p0: from,
            p1: CGPoint(x: from.x + (to.x - from.x) / 3, y: from.y + (to.y - from.y) / 3),
            p2: CGPoint(x: from.x + (to.x - from.x) * 2 / 3, y: from.y + (to.y - from.y) * 2 / 3),
            p3: to
        )
    }

    func point(at t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x
        let y = u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 原版 Web 路由飞鸟 (.rt-flier / routing.js / routing.css 1:1 对齐)

/// Web 原版 FLIER:
/// - 面向右侧，喙尖叼着当前请求的 packet 能量点（能量点中心与舞台虚线点 1:1 重合）
/// - 远侧翅膀与近侧翅膀自肩部按 rtflap 0.42s 周期真实扑动（scaleY: 1.0 -> -0.62，伴随 -8° 扇动倾角）
/// - 躯干、白色腹部、近侧翅膀白条纹与喙部 1:1 纯量级对齐 Web SVG
private enum RoutingMagpieBird {
    private static let baseTransform = CGAffineTransform(translationX: -6.5, y: 3.2)
        .concatenating(CGAffineTransform(scaleX: 1.2, y: 1.2))

    private static let farShoulder = CGPoint(x: -11.5, y: -3.3)
    private static let nearShoulder = CGPoint(x: -12.0, y: -3.0)

    private static let farWingPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -14.5, y: -3.4))
        p.addCurve(to: CGPoint(x: -8.6, y: -18.6), control1: CGPoint(x: -16.5, y: -9.5), control2: CGPoint(x: -14.2, y: -15.0))
        p.addCurve(to: CGPoint(x: -9.2, y: -3.2), control1: CGPoint(x: -9.4, y: -12.6), control2: CGPoint(x: -9.6, y: -7.4))
        p.closeSubpath()
        return p
    }()

    private static let tailPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -31.5, y: 3.1))
        p.addLine(to: CGPoint(x: -18.6, y: -1.8))
        p.addLine(to: CGPoint(x: -17.4, y: 1.2))
        p.addLine(to: CGPoint(x: -30.8, y: 4.6))
        p.closeSubpath()
        return p.applying(baseTransform)
    }()

    private static let bodyPath: Path = {
        var p = Path()
        p.addEllipse(in: CGRect(x: -12.2 - 7.6, y: -1.4 - 3.9, width: 15.2, height: 7.8))
        p.addEllipse(in: CGRect(x: -4.9 - 3.1, y: -3.7 - 3.1, width: 6.2, height: 6.2))
        p.move(to: CGPoint(x: -2.3, y: -4.8))
        p.addLine(to: CGPoint(x: 1.4, y: -3.3))
        p.addLine(to: CGPoint(x: -2.3, y: -2.2))
        p.closeSubpath()
        return p.applying(baseTransform)
    }()

    private static let bellyPath: Path = {
        var p = Path()
        p.addEllipse(in: CGRect(x: -12.8 - 4.3, y: 0.4 - 1.6, width: 8.6, height: 3.2))
        return p.applying(baseTransform)
    }()

    private static let nearWingPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -15.6, y: -3.2))
        p.addCurve(to: CGPoint(x: -8.4, y: -20.4), control1: CGPoint(x: -17.8, y: -10.2), control2: CGPoint(x: -15.2, y: -16.4))
        p.addCurve(to: CGPoint(x: -8.8, y: -2.8), control1: CGPoint(x: -9.3, y: -13.6), control2: CGPoint(x: -9.4, y: -7.8))
        p.closeSubpath()
        return p
    }()

    private static let nearBarPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -14.6, y: -5.6))
        p.addCurve(to: CGPoint(x: -10.4, y: -17.2), control1: CGPoint(x: -15.4, y: -10.4), control2: CGPoint(x: -13.8, y: -14.4))
        return p
    }()

    private static let dotPath = Path(ellipseIn: CGRect(x: -4.5, y: -4.5, width: 9, height: 9))

    static func draw(in context: inout GraphicsContext, color: Color, progress: Double, isReturn: Bool) {
        let p = min(max(CGFloat(progress), 0), 1)
        let (nearScaleY, nearSkew) = flapTransform(t: p)
        let farP = CGFloat((progress + 0.0714).truncatingRemainder(dividingBy: 1.0))
        let (farScaleY, farSkew) = flapTransform(t: farP)

        let farWingTransform = wingTransform(shoulder: farShoulder, scaleY: farScaleY, skew: farSkew)
            .concatenating(baseTransform)
        context.fill(farWingPath.applying(farWingTransform), with: .color(color.opacity(0.45)))

        context.fill(tailPath, with: .color(color))
        context.fill(bodyPath, with: .color(color))
        context.fill(bellyPath, with: .color(MagpieTheme.card))

        let nearWingTransform = wingTransform(shoulder: nearShoulder, scaleY: nearScaleY, skew: nearSkew)
            .concatenating(baseTransform)
        context.fill(nearWingPath.applying(nearWingTransform), with: .color(color))
        context.stroke(
            nearBarPath.applying(nearWingTransform),
            with: .color(MagpieTheme.card),
            style: StrokeStyle(lineWidth: 1.3 * 1.2, lineCap: .round)
        )

        if isReturn {
            context.fill(dotPath, with: .color(MagpieTheme.card))
            context.stroke(dotPath, with: .color(color), style: StrokeStyle(lineWidth: 2.25))
        } else {
            context.fill(dotPath, with: .color(color))
        }
    }

    private static func flapTransform(t: CGFloat) -> (scaleY: CGFloat, skew: CGFloat) {
        if t <= 0.55 {
            let u = t / 0.55
            let s = u * u * (3.0 - 2.0 * u)
            return (1.0 - 1.62 * s, (-8.0 * .pi / 180.0) * s)
        } else {
            let u = (t - 0.55) / 0.45
            let s = u * u * (3.0 - 2.0 * u)
            return (-0.62 + 1.62 * s, (-8.0 * .pi / 180.0) * (1.0 - s))
        }
    }

    private static func wingTransform(shoulder: CGPoint, scaleY: CGFloat, skew: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: -shoulder.x, y: -shoulder.y)
            .concatenating(CGAffineTransform(a: 1.0, b: 0.0, c: tan(skew), d: scaleY, tx: 0.0, ty: 0.0))
            .concatenating(CGAffineTransform(translationX: shoulder.x, y: shoulder.y))
    }
}
