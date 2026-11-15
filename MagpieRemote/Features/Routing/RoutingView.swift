import SwiftUI

/// Routing 页：读取真实的网关路由历史（`/api/gateway/history`），
/// 展示每次请求的模型、提供方、路由组、尝试顺序与延迟。
struct RoutingView: View {
    @Environment(AppModel.self) private var app
    @State private var viewModel = RoutingViewModel()
    @State private var selectedRoute: GatewayRouteDTO?
    @State private var searchText = ""

    private var routes: [GatewayRouteDTO] {
        guard !searchText.isEmpty else { return viewModel.routes }
        let q = searchText.lowercased()
        return viewModel.routes.filter {
            ($0.model?.lowercased().contains(q) ?? false)
                || ($0.provider?.lowercased().contains(q) ?? false)
                || ($0.agent?.lowercased().contains(q) ?? false)
                || ($0.group?.displayName.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        MagpieNavigationContainer {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if !viewModel.liveRoutes.isEmpty {
                        liveNowSection
                    }
                    statsRow

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    liveSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .navigationTitle(String(localized: "Routing"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: String(localized: "搜索模型、提供方或 Agent…"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let client = app.client {
                            Task { await viewModel.load(client: client) }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(String(localized: "刷新路由记录"))
                }
            }
            .refreshable {
                if let client = app.client { await viewModel.load(client: client) }
            }
            .task {
                if let client = app.client {
                    viewModel.startPolling(client: client)
                }
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .sheet(item: $selectedRoute) { route in
                RoutingRouteDetailSheet(route: route)
            }
        }
    }

    // MARK: - 顶部
    private var hero: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), MagpieTheme.accent.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .shadow(color: Color(hex: "8b5cf6").opacity(0.35), radius: 12, x: 0, y: 6)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "实时路由"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(MagpieTheme.textPrimary)

                    HStack(spacing: 6) {
                        MagpiePulseDot(color: viewModel.liveRoutes.isEmpty ? MagpieTheme.green : MagpieTheme.accent)
                        Text(
                            viewModel.liveRoutes.isEmpty
                                ? String(localized: "网关正在决定每一次请求的去向")
                                : String(localized: "\(viewModel.liveRoutes.count) 个请求正在实时路由")
                        )
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textSecondary)
                        .contentTransition(.numericText())
                    }
                }

                Spacer()

                if let updated = viewModel.lastUpdated {
                    Text(RoutingFormat.time(updated))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }
        }
        .magpieCard()
    }

    // MARK: - 正在路由
    private var liveNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MagpieSectionLabel(
                title: String(localized: "正在路由"),
                detail: String(localized: "\(viewModel.liveRoutes.count) 个请求进行中")
            )

            LazyVStack(spacing: 10) {
                ForEach(viewModel.liveRoutes) { route in
                    Button {
                        selectedRoute = route
                    } label: {
                        routeCard(route)
                    }
                    .buttonStyle(MagpiePressableStyle())
                    .transition(.magpieContent)
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.85), value: viewModel.liveRoutes.map(\.id))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(viewModel.routes.count)",
                title: String(localized: "最近请求"),
                icon: "arrow.left.arrow.right",
                tint: MagpieTheme.accent
            )
            statCard(
                value: "\(viewModel.reroutedCount)",
                title: String(localized: "发生转移"),
                icon: "arrow.triangle.swap",
                tint: MagpieTheme.cyan
            )
            statCard(
                value: "\(viewModel.errorCount)",
                title: String(localized: "失败"),
                icon: "exclamationmark.triangle.fill",
                tint: viewModel.errorCount > 0 ? MagpieTheme.red : MagpieTheme.textMuted
            )
        }
    }

    private func statCard(value: String, title: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            MagpieGradientNumber(text: value, tint: tint, size: 22)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(MagpieTheme.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .magpieCard(padding: 12)
    }

    // MARK: - 列表
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MagpieSectionLabel(
                title: String(localized: "最近请求"),
                detail: viewModel.isLoading ? String(localized: "更新中") : nil
            )

            if routes.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(routes.prefix(60)) { route in
                        Button {
                            selectedRoute = route
                        } label: {
                            routeCard(route)
                        }
                        .buttonStyle(MagpiePressableStyle())
                        .transition(.magpieContent)
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.85), value: routes.map(\.id))
                .animation(.easeInOut(duration: 0.22), value: routes.map(\.isPending))
            }
        }
    }

    private func routeCard(_ route: GatewayRouteDTO) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(statusColor(route))
                .frame(width: 3)
                .padding(.vertical, 8)
                .padding(.leading, 10)
                .shadow(
                    color: statusColor(route).opacity(route.isPending ? 0.85 : 0.3),
                    radius: route.isPending ? 5 : 2
                )
                .animation(.easeInOut(duration: 0.6), value: route.isPending)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    MagpieIconView(icon: route.agent, name: route.agent ?? "agent", size: 28, cornerRadius: 7)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(route.model ?? String(localized: "未知模型"))
                                .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .lineLimit(1)

                            if route.isPending {
                                HStack(spacing: 4) {
                                    MagpiePulseDot(color: MagpieTheme.accent)
                                    MagpieStatusChip(text: String(localized: "进行中"), color: MagpieTheme.accent)
                                }
                            } else if route.isError {
                                MagpieStatusChip(text: RoutingFormat.statusText(route), color: MagpieTheme.red)
                            } else if route.canceled == true {
                                MagpieStatusChip(text: String(localized: "已取消"), color: MagpieTheme.amber)
                            } else {
                                MagpieStatusChip(text: String(localized: "成功"), color: MagpieTheme.green)
                            }
                        }

                        HStack(spacing: 5) {
                            if let group = route.group {
                                Image(systemName: "square.3.layers.3d")
                                    .font(.system(size: 9))
                                Text(group.displayName)
                                Text("·")
                            }
                            Text(route.provider ?? "—")
                        }
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text(RoutingFormat.time(route.date))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                HStack(spacing: 12) {
                    metric(icon: "clock", value: RoutingFormat.latency(route.millis), tint: MagpieTheme.textSecondary)
                    metric(icon: "number", value: RoutingFormat.tokens(route.tokens), tint: MagpieTheme.textSecondary)
                    metric(icon: "dollarsign", value: RoutingFormat.cost(route.cost), tint: MagpieTheme.green)

                    Spacer()

                    if let order = route.order, order.count > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.swap")
                            Text("\(order.count) 个候选")
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MagpieTheme.cyan)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
                }

                if route.isPending {
                    RoutePendingBar(tint: statusColor(route))
                        .frame(height: 3)
                        .clipShape(Capsule())
                        .padding(.trailing, 2)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MagpieTheme.card.opacity(0.78))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), MagpieTheme.border.opacity(0.85), Color.black.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: statusColor(route).opacity(0.08), radius: 12, x: 0, y: 5)
        )
    }

    private func metric(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(tint)
    }

    private func statusColor(_ route: GatewayRouteDTO) -> Color {
        if route.isError { return MagpieTheme.red }
        if route.isPending { return MagpieTheme.accent }
        if route.canceled == true { return MagpieTheme.amber }
        return MagpieTheme.green
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 34))
                .foregroundStyle(MagpieTheme.textMuted.opacity(0.65))
            Text(String(localized: "还没有路由记录"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MagpieTheme.textPrimary)
            Text(String(localized: "当 Agent 通过 magpie 网关发起请求时，这里的实时决策链会显示模型、账号与故障转移顺序。"))
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .magpieCard()
    }

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
}

// MARK: - 进行中的流动条
/// 请求还在进行时沿卡片底部扫过的一条微光。
private struct RoutePendingBar: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Capsule().fill(tint.opacity(0.35))
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.6) / 1.6
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, tint.opacity(0.9), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(width * 0.35, 56))
                            .offset(x: -width * 0.35 + width * 1.35 * phase)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - 路由详情
private struct RoutingRouteDetailSheet: View {
    let route: GatewayRouteDTO
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if let group = route.group {
                        groupCard(group)
                    }

                    if let order = route.order, !order.isEmpty {
                        orderSection(order)
                    }

                    if let error = route.error, !error.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            MagpieSectionLabel(title: String(localized: "错误"))
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(MagpieTheme.red)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .magpieCard()
                    }

                    metaCard
                }
                .padding(16)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "路由详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MagpieIconView(icon: route.agent, name: route.agent ?? "agent", size: 44, cornerRadius: 11)

                VStack(alignment: .leading, spacing: 3) {
                    Text(route.model ?? String(localized: "未知模型"))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(route.provider ?? "—")
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Spacer()

                if route.isError {
                    MagpieStatusChip(text: RoutingFormat.statusText(route), color: MagpieTheme.red, icon: "xmark")
                } else if route.isPending {
                    MagpieStatusChip(text: String(localized: "进行中"), color: MagpieTheme.accent)
                } else {
                    MagpieStatusChip(text: String(localized: "成功"), color: MagpieTheme.green, icon: "checkmark")
                }
            }

            Divider().background(MagpieTheme.borderSubtle)

            HStack {
                detailMetric(String(localized: "延迟"), RoutingFormat.latency(route.millis))
                Spacer()
                detailMetric(String(localized: "Token"), RoutingFormat.tokens(route.tokens))
                Spacer()
                detailMetric(String(localized: "费用"), RoutingFormat.cost(route.cost))
                Spacer()
                detailMetric(String(localized: "时间"), RoutingFormat.time(route.date))
            }
        }
        .magpieCard()
    }

    private func detailMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(MagpieTheme.textPrimary)
        }
    }

    private func groupCard(_ group: GatewayGroupRefDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MagpieSectionLabel(title: String(localized: "路由组"))
                Spacer()
                Text(RoutingFormat.strategyName(group.routing))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(MagpieTheme.accentSoft)
                    .foregroundStyle(MagpieTheme.accent)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Image(systemName: group.auto == true ? "wand.and.stars" : "square.3.layers.3d")
                    .foregroundStyle(MagpieTheme.accent)
                Text(group.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Spacer()
                if let members = group.members {
                    Text("\(members.count) 个成员")
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }
        }
        .magpieCard()
    }

    private func orderSection(_ order: [GatewayWeighedDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MagpieSectionLabel(
                title: String(localized: "候选顺序"),
                detail: String(localized: "网关实际权衡的账号")
            )

            VStack(spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, seat in
                    HStack(spacing: 11) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(index == 0 ? MagpieTheme.accent : MagpieTheme.textMuted)
                            .frame(width: 20, height: 20)
                            .background(index == 0 ? MagpieTheme.accentSoft : MagpieTheme.pill)
                            .clipShape(Circle())

                        MagpieIconView(icon: seat.icon ?? seat.provider, name: seat.name ?? seat.provider ?? "provider", size: 26, cornerRadius: 7)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(seat.name ?? seat.provider ?? "—")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                if seat.fallback == true {
                                    MagpieStatusChip(text: String(localized: "备用"), color: MagpieTheme.textMuted)
                                }
                                if seat.fast == true {
                                    MagpieStatusChip(text: "FAST", color: MagpieTheme.cyan)
                                }
                            }
                            HStack(spacing: 4) {
                                Text(seat.who ?? seat.kind ?? "")
                                if let model = seat.model, !model.isEmpty {
                                    Text("·")
                                    Text(model)
                                        .lineLimit(1)
                                }
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(MagpieTheme.textMuted)
                        }

                        Spacer(minLength: 4)

                        if let percent = seat.usedPercent {
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(percent)%")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(percent >= 90 ? MagpieTheme.red : MagpieTheme.textSecondary)
                                ProgressView(value: min(Double(percent), 100), total: 100)
                                    .tint(percent >= 90 ? MagpieTheme.red : MagpieTheme.accent)
                                    .frame(width: 52)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.86)
                            .delay(Double(index) * 0.035),
                        value: appeared
                    )

                    if index < order.count - 1 {
                        Divider()
                            .background(MagpieTheme.borderSubtle)
                            .padding(.leading, 63)
                    }
                }
            }
            .magpieCard(padding: 0)
        }
        .onAppear {
            appeared = true
        }
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            MagpieSectionLabel(title: String(localized: "请求"))

            row(String(localized: "Agent"), route.agent)
            row(String(localized: "会话"), route.session)
            row(String(localized: "调用 Key"), route.callerKeyName)
            row(String(localized: "类型"), route.kind)
            if let moved = route.moved {
                row(String(localized: "改派"), moved.why ?? moved.to)
            }
            if let served = route.served, !served.isEmpty {
                row(String(localized: "实际服务"), served)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .magpieCard()
    }

    private func row(_ title: String, _ value: String?) -> some View {
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
