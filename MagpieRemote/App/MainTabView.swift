import SwiftUI

// MARK: - 官方全量页面定义
/// 包含 Magpie Remote 支持的所有功能页面及其元数据与目标视图。
enum AppPage: String, Hashable, CaseIterable, Identifiable {
    case agents
    case sessions
    case library
    case providers
    case routing
    case groups
    case gateway
    case usage
    case masking
    case plugins
    case settings
    case about
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .agents: return String(localized: "Agents")
        case .sessions: return String(localized: "Sessions")
        case .library: return String(localized: "Library")
        case .providers: return String(localized: "Providers")
        case .routing: return String(localized: "路由")
        case .groups: return String(localized: "路由组")
        case .gateway: return String(localized: "网关")
        case .usage: return String(localized: "用量统计")
        case .masking: return String(localized: "脱敏规则")
        case .plugins: return String(localized: "扩展插件")
        case .settings: return String(localized: "客户端设置")
        case .about: return String(localized: "关于")
        case .more: return String(localized: "更多")
        }
    }

    var shortTitle: String {
        switch self {
        case .agents: return String(localized: "Agents")
        case .sessions: return String(localized: "会话")
        case .library: return String(localized: "知识库")
        case .providers: return String(localized: "模型")
        case .routing: return String(localized: "路由")
        case .groups: return String(localized: "路由组")
        case .gateway: return String(localized: "网关")
        case .usage: return String(localized: "用量")
        case .masking: return String(localized: "脱敏")
        case .plugins: return String(localized: "插件")
        case .settings: return String(localized: "设置")
        case .about: return String(localized: "关于")
        case .more: return String(localized: "更多")
        }
    }

    var subtitle: String {
        switch self {
        case .agents: return String(localized: "智能体与执行器")
        case .sessions: return String(localized: "历史对话与记录")
        case .library: return String(localized: "技能、指令与记忆")
        case .providers: return String(localized: "模型接入与鉴权")
        case .routing: return String(localized: "实时决策链与备选")
        case .groups: return String(localized: "策略与负载均衡")
        case .gateway: return String(localized: "调用密钥与权限")
        case .usage: return String(localized: "消耗与配额走势")
        case .masking: return String(localized: "敏感数据过滤")
        case .plugins: return String(localized: "扩展插件与市场")
        case .settings: return String(localized: "服务器与偏好设置")
        case .about: return String(localized: "版本、致谢与隐私")
        case .more: return String(localized: "全部页面与系统设置")
        }
    }

    var icon: String {
        switch self {
        case .agents: return "terminal"
        case .sessions: return "bubble.left.and.bubble.right"
        case .library: return "books.vertical"
        case .providers: return "key.radiowaves.forward"
        case .routing: return "arrow.triangle.branch"
        case .groups: return "square.3.layers.3d"
        case .gateway: return "server.rack"
        case .usage: return "chart.bar.xaxis"
        case .masking: return "shield.lefthalf.filled"
        case .plugins: return "puzzlepiece.extension"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        case .more: return "ellipsis.circle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .agents: return [MagpieTheme.accent, Color(hex: "6366f1")]
        case .sessions: return [Color(hex: "0284c7"), Color(hex: "2563eb")]
        case .library: return [Color(hex: "8b5cf6"), Color(hex: "7c3aed")]
        case .providers: return [Color(hex: "f59e0b"), Color(hex: "d97706")]
        case .routing: return [Color(hex: "9333ea"), Color(hex: "6b21a8")]
        case .groups: return [Color(hex: "0ea5e9"), Color(hex: "0284c7")]
        case .gateway: return [Color(hex: "ea580c"), Color(hex: "c2410c")]
        case .usage: return [Color(hex: "10b981"), Color(hex: "059669")]
        case .masking: return [Color(hex: "14b8a6"), Color(hex: "0d9488")]
        case .plugins: return [Color(hex: "ec4899"), Color(hex: "db2777")]
        case .settings: return [Color(hex: "64748b"), Color(hex: "334155")]
        case .about: return [MagpieTheme.accent, MagpieTheme.purple]
        case .more: return [MagpieTheme.accent, MagpieTheme.purple]
        }
    }

    var primaryColor: Color {
        colors.first ?? MagpieTheme.accent
    }

    @MainActor
    @ViewBuilder
    var destination: some View {
        switch self {
        case .agents: AgentsView()
        case .sessions: SessionsView()
        case .library: LibraryView()
        case .providers: ProvidersView()
        case .routing: RoutingView()
        case .groups: GroupsView()
        case .gateway: GatewayView()
        case .usage: UsageView()
        case .masking: MaskingView()
        case .plugins: PluginsView()
        case .settings: SettingsView()
        case .about: AboutView()
        case .more: MoreView()
        }
    }
}

// MARK: - 底部 TabBar 自定义存储中心
@MainActor
@Observable
final class TabStore {
    static let shared = TabStore()

    private let storageKey = "magpie_custom_tabs_v2"
    static let defaultPinned: [AppPage] = [.agents, .sessions, .routing, .providers]

    var pinnedTabs: [AppPage] {
        didSet {
            save()
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey) {
            let keys = raw.split(separator: ",").map { String($0) }
            let loaded = keys.compactMap { AppPage(rawValue: $0) }.filter { $0 != .more }
            if loaded.count >= 2 {
                self.pinnedTabs = loaded
                return
            }
        }
        self.pinnedTabs = Self.defaultPinned
    }

    var unpinnedTabs: [AppPage] {
        AppPage.allCases.filter { $0 != .more && !pinnedTabs.contains($0) }
    }

    func pinTab(_ page: AppPage) {
        guard page != .more else { return }
        guard !pinnedTabs.contains(page) else { return }
        guard pinnedTabs.count < 4 else { return }
        pinnedTabs.append(page)
    }

    func unpinTab(_ page: AppPage) {
        guard pinnedTabs.count > 2 else { return }
        pinnedTabs.removeAll { $0 == page }
    }

    func moveTab(fromOffsets: IndexSet, toOffset: Int) {
        pinnedTabs.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func resetToDefault() {
        pinnedTabs = Self.defaultPinned
    }

    private func save() {
        let raw = pinnedTabs.map(\.rawValue).joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}

// MARK: - 主界面 TabView
/// 与官方 Web UI 结构对齐，全面采用 iOS 26/27 Apple 原生 Liquid Glass 语言：
/// - iPhone（compact）：底部 Liquid Glass 浮动栏，用户可自定义放置哪些常用 Tab（2-4 个）。
///   点击「更多」弹出的是「标签气泡」（MoreTagBubbleView）而不是页面，点击具体气泡后才进入页面。
/// - iPad / 大屏（regular）：`.sidebarAdaptable` 展开为结构化分组侧边栏。
struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var tabStore = TabStore.shared
    @State private var compactSelection: AppPage = MainTabView.initialPage
    @State private var regularSelection: AppPage = MainTabView.initialPage
    @State private var isMoreBubblePresented = false
    @State private var activePresentedPage: AppPage?
    @State private var showingCustomizationSheet = false

    /// DEBUG 联调：`MAGPIE_DEV_TAB=providers` 等直接打开某页用于截图核对。
    private static var initialPage: AppPage {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["MAGPIE_DEV_TAB"],
           let page = AppPage(rawValue: raw) {
            return page
        }
        #endif
        return .agents
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if horizontalSizeClass == .compact {
                compactTabs
            } else {
                regularTabs
            }

            if horizontalSizeClass == .compact, isMoreBubblePresented {
                // 点击全屏半透明遮罩快速关闭
                Color.black.opacity(colorScheme == .dark ? 0.38 : 0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isMoreBubblePresented = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)

                // 竖直排列的气泡图标
                MoreTagBubbleView(
                    unpinnedTabs: tabStore.unpinnedTabs,
                    onSelectPage: { page in
                        isMoreBubblePresented = false
                        activePresentedPage = page
                    },
                    onOpenCustomization: {
                        isMoreBubblePresented = false
                        showingCustomizationSheet = true
                    }
                )
                .padding(.trailing, 18)
                .padding(.bottom, 84)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.72, anchor: .bottomTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
                ))
                .zIndex(3)
            }
        }
        .sheet(item: $activePresentedPage) { page in
            NavigationStack {
                page.destination
                    .environment(\.magpieEmbeddedNavigation, true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCustomizationSheet) {
            TabBarCustomizationSheet()
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["MAGPIE_DEV_TAB"] == "more" {
                compactSelection = tabStore.pinnedTabs.first ?? .agents
                isMoreBubblePresented = true
            }
            #endif
        }
    }

    /// 自定义底栏的选中状态：切换页面时顺便关闭「更多」气泡。
    private var barSelection: Binding<AppPage> {
        Binding(
            get: { compactSelection },
            set: { newValue in
                compactSelection = newValue
                withAnimation(.snappy(duration: 0.2)) {
                    isMoreBubblePresented = false
                }
            }
        )
    }

    // MARK: - iPhone（自定义 Liquid Glass 底栏 + 气泡 More）
    private var compactTabs: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $compactSelection) {
                ForEach(tabStore.pinnedTabs) { page in
                    Tab(page.shortTitle, systemImage: page.icon, value: page) {
                        page.destination
                            .toolbar(.hidden, for: .tabBar)
                    }
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .onChange(of: tabStore.pinnedTabs) { _, newPinned in
                if !newPinned.contains(compactSelection) {
                    compactSelection = newPinned.first ?? .agents
                }
            }

            MagpieLiquidTabBar(
                pinnedTabs: tabStore.pinnedTabs,
                selectedTab: barSelection,
                isMoreOpen: isMoreBubblePresented,
                onToggleMore: {
                    MagpieHaptics.light()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        isMoreBubblePresented.toggle()
                    }
                }
            )
            .padding(.bottom, 8)
        }
    }

    // MARK: - iPad / 大屏
    private var regularTabs: some View {
        TabView(selection: $regularSelection) {
            TabSection("Work") {
                Tab(value: AppPage.agents) {
                    AgentsView()
                } label: {
                    Label("Agents", systemImage: "terminal")
                }

                Tab(value: AppPage.sessions) {
                    SessionsView()
                } label: {
                    Label("Sessions", systemImage: "bubble.left.and.bubble.right")
                }

                Tab(value: AppPage.library) {
                    LibraryView()
                } label: {
                    Label("Library", systemImage: "books.vertical")
                }
            }

            TabSection("Models") {
                Tab(value: AppPage.providers) {
                    ProvidersView()
                } label: {
                    Label("Providers", systemImage: "key.radiowaves.forward")
                }

                Tab(value: AppPage.routing) {
                    RoutingView()
                } label: {
                    Label("Routing", systemImage: "arrow.triangle.branch")
                }

                Tab(value: AppPage.groups) {
                    GroupsView()
                } label: {
                    Label("Routing groups", systemImage: "square.3.layers.3d")
                }

                Tab(value: AppPage.gateway) {
                    GatewayView()
                } label: {
                    Label("Gateway", systemImage: "server.rack")
                }
            }

            TabSection("Insights") {
                Tab(value: AppPage.usage) {
                    UsageView()
                } label: {
                    Label("Usage", systemImage: "chart.bar.xaxis")
                }

                Tab(value: AppPage.masking) {
                    MaskingView()
                } label: {
                    Label("Masking", systemImage: "shield.lefthalf.filled")
                }
            }

            TabSection("Extend") {
                Tab(value: AppPage.plugins) {
                    PluginsView()
                } label: {
                    Label("Plugins", systemImage: "puzzlepiece.extension")
                }
            }

            Tab(value: AppPage.settings) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Tab(value: AppPage.about) {
                AboutView()
            } label: {
                Label("About", systemImage: "info.circle")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(MagpieTheme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

// MARK: - 浮动 Liquid Glass 底部 TabBar（iOS 26/27 现代风格）
struct MagpieLiquidTabBar: View {
    let pinnedTabs: [AppPage]
    @Binding var selectedTab: AppPage
    var isMoreOpen: Bool = false
    var onToggleMore: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(pinnedTabs) { tab in
                tabButton(tab)
            }

            // More (更多) 导航按钮
            moreButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(MagpieTheme.card.opacity(colorScheme == .dark ? 0.78 : 0.88))
        )
        .magpieLiquidSurface(cornerRadius: 999, interactive: true)
        .overlay(
            Capsule()
                .stroke(MagpieTheme.borderSubtle, lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .frame(maxWidth: 420)
    }

    private func tabButton(_ tab: AppPage) -> some View {
        let isSelected = !isMoreOpen && selectedTab == tab

        return Button {
            if selectedTab != tab || isMoreOpen {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 17 : 16, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? tab.primaryColor : MagpieTheme.textMuted)

                Text(tab.shortTitle)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? tab.primaryColor : MagpieTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background {
                if isSelected {
                    Capsule()
                        .fill(tab.primaryColor.opacity(colorScheme == .dark ? 0.20 : 0.14))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var moreButton: some View {
        let isSelected = selectedTab == .more || isMoreOpen
        return Button {
            if let onToggleMore {
                onToggleMore()
            } else if selectedTab != .more {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    selectedTab = .more
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? "ellipsis.circle.fill" : "ellipsis.circle")
                    .font(.system(size: isSelected ? 17 : 16, weight: .bold))
                    .foregroundStyle(isSelected ? MagpieTheme.accent : MagpieTheme.textMuted)

                Text(String(localized: "更多"))
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? MagpieTheme.accent : MagpieTheme.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background {
                if isSelected {
                    Capsule()
                        .fill(MagpieTheme.accent.opacity(colorScheme == .dark ? 0.22 : 0.16))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 点击 More 弹出的「竖直气泡图标」视图（MoreTagBubbleView）
/// 严格遵循竖直气泡图标设计：每个次级功能作为一个独立高质感圆形气泡按钮垂直排布，
/// 左侧伴随半透明毛玻璃标签胶囊，点击任意位置或外部即可轻触关闭，提供极致灵动体验。
struct MoreTagBubbleView: View {
    let unpinnedTabs: [AppPage]
    let onSelectPage: (AppPage) -> Void
    let onOpenCustomization: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAppeared = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 11) {
            ForEach(unpinnedTabs) { page in
                bubbleRow(
                    title: page.shortTitle,
                    icon: page.icon,
                    color: page.primaryColor
                ) {
                    onSelectPage(page)
                }
            }

            bubbleRow(
                title: String(localized: "自定义底栏"),
                icon: "slider.horizontal.3",
                color: MagpieTheme.accent,
                isCustomization: true
            ) {
                onOpenCustomization()
            }
        }
        .scaleEffect(isAppeared ? 1 : 0.75, anchor: .bottomTrailing)
        .opacity(isAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                isAppeared = true
            }
        }
    }

    private func bubbleRow(
        title: String,
        icon: String,
        color: Color,
        isCustomization: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            MagpieHaptics.light()
            action()
        } label: {
            HStack(spacing: 9) {
                // 左侧胶囊标签
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background(
                        Capsule()
                            .fill(MagpieTheme.card.opacity(colorScheme == .dark ? 0.88 : 0.94))
                    )
                    .overlay(
                        Capsule()
                            .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 6, x: 0, y: 2)

                // 右侧圆形气泡图标
                ZStack {
                    Circle()
                        .fill(isCustomization ? MagpieTheme.card.opacity(0.92) : color.opacity(0.18))
                        .frame(width: 48, height: 48)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.45 : 0.85),
                                    color.opacity(0.35),
                                    .white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }
                .magpieLiquidSurface(cornerRadius: 24, interactive: true)
                .shadow(color: color.opacity(isCustomization ? 0.15 : 0.35), radius: 8, x: 0, y: 3.5)
            }
        }
        .buttonStyle(MagpieBubblePressableStyle())
    }
}

// MARK: - 气泡弹性微按压效果
struct MagpieBubblePressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - 底部栏自定义配置 Sheet
struct TabBarCustomizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = TabStore.shared

    var body: some View {
        NavigationStack {
            List {
                // 实时预览卡片
                Section {
                    VStack(spacing: 12) {
                        Text(String(localized: "实时效果预览"))
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.textMuted)

                        miniPreviewBar
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // 已固定的标签
                Section {
                    ForEach(store.pinnedTabs) { page in
                        HStack(spacing: 12) {
                            pageIcon(page)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(page.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Text(page.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }

                            Spacer()

                            if store.pinnedTabs.count > 2 {
                                Button {
                                    MagpieHaptics.light()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        store.unpinTab(page)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(MagpieTheme.red)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onMove { from, to in
                        store.moveTab(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text(String(localized: "显示在底部栏（\(store.pinnedTabs.count)/4，可拖动排序）"))
                } footer: {
                    Text(String(localized: "底部栏至少保留 2 个，最多 4 个标签，第 5 个固定为「更多」气泡。"))
                }

                // 气泡中的其他标签
                if !store.unpinnedTabs.isEmpty {
                    Section {
                        ForEach(store.unpinnedTabs) { page in
                            HStack(spacing: 12) {
                                pageIcon(page)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(MagpieTheme.textPrimary)
                                    Text(page.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(MagpieTheme.textMuted)
                                }

                                Spacer()

                                if store.pinnedTabs.count < 4 {
                                    Button {
                                        MagpieHaptics.light()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            store.pinTab(page)
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(MagpieTheme.green)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "在「更多」气泡中显示"))
                    } footer: {
                        if store.pinnedTabs.count >= 4 {
                            Text(String(localized: "底部栏已满（4/4），移除现有标签后可添加新标签。"))
                        }
                    }
                }

                // 恢复默认操作
                Section {
                    Button(role: .destructive) {
                        MagpieHaptics.medium()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            store.resetToDefault()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "恢复默认底部栏"))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "自定义底部栏"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                }
            }
        }
    }

    private func pageIcon(_ page: AppPage) -> some View {
        ZStack {
            Circle()
                .fill(page.primaryColor.opacity(0.18))
                .frame(width: 32, height: 32)

            Circle()
                .stroke(page.primaryColor.opacity(0.25), lineWidth: 0.8)
                .frame(width: 32, height: 32)

            Image(systemName: page.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(page.primaryColor)
        }
    }

    private var miniPreviewBar: some View {
        HStack(spacing: 8) {
            ForEach(store.pinnedTabs) { tab in
                VStack(spacing: 2) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 12))
                    Text(tab.title)
                        .font(.system(size: 8))
                        .lineLimit(1)
                }
                .foregroundStyle(tab == store.pinnedTabs.first ? MagpieTheme.accent : MagpieTheme.textMuted)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 2) {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 12))
                Text(String(localized: "更多"))
                    .font(.system(size: 8))
            }
            .foregroundStyle(MagpieTheme.textMuted)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.8))
        .frame(maxWidth: 320)
    }
}
