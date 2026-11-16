import SwiftUI

/// 添加 Provider：对齐官方 Add 表单。
/// 预设按 Partner / Vendor / Relay / Local / Remote 分组，支持区域/套餐、
/// 自定义端点、保存前检测 API 与真实连通性结果。
struct AddProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @Environment(ProvidersViewModel.self) private var viewModel

    @State private var searchText = ""
    @State private var selectedPreset: PresetDTO?
    @State private var selectedRegion: PresetRegionDTO?
    @State private var isCustom = false

    // 表单状态
    @State private var customID = ""
    @State private var customName = ""
    @State private var customHost = ""
    @State private var apiKey = ""
    @State private var customAPI = "chat"
    @State private var isKeyVisible = false
    @State private var allowSearches = false
    @State private var unredacted = false
    @State private var vertexProject = ""
    @State private var vertexLocation = "global"

    // 交互状态
    @State private var isTesting = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var detections: [ProviderDetectionDTO] = []
    @State private var testError: String?
    @State private var isFetchingModels = false
    @State private var fetchedModels: [ProviderListedModelDTO] = []
    @State private var fetchError: String?
    @State private var showingSignIn = false
    @State private var pluginSignIn: PluginSubDTO?

    private var allPresets: [PresetDTO] { viewModel.presets }

    private var partners: [PresetDTO] {
        filtered(allPresets.filter { $0.isPartner })
    }

    private var vendors: [PresetDTO] {
        filtered(allPresets.filter { !$0.isPartner && ($0.kind == "vendor" || $0.kind == nil) })
    }

    private var relays: [PresetDTO] {
        filtered(allPresets.filter { !$0.isPartner && $0.kind == "relay" })
    }

    private var localPresets: [PresetDTO] {
        filtered(allPresets.filter { !$0.isPartner && $0.kind == "local" })
    }

    private var remotePresets: [PresetDTO] {
        filtered(allPresets.filter { !$0.isPartner && $0.kind == "remote" })
    }

    private func filtered(_ list: [PresetDTO]) -> [PresetDTO] {
        guard !searchText.isEmpty else { return list }
        let query = searchText.lowercased()
        return list.filter {
            $0.name.lowercased().contains(query)
                || $0.id.lowercased().contains(query)
                || ($0.short?.lowercased().contains(query) ?? false)
                || ($0.localizedNote?.lowercased().contains(query) ?? false)
        }
    }

    private var regions: [PresetRegionDTO] { selectedPreset?.regions ?? [] }

    private var selectedBaseURL: String {
        if isCustom { return customHost.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let region = selectedRegion { return region.chat ?? region.responses ?? region.anthropic ?? "" }
        return selectedPreset?.host ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if selectedPreset != nil || isCustom {
                        configureForm
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        presetsList
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.88), value: selectedPreset?.id)
                .animation(.spring(response: 0.4, dampingFraction: 0.88), value: isCustom)
            }
            .magpiePageBackground()
            .navigationTitle(selectedPreset?.name ?? (isCustom ? String(localized: "自定义 Provider") : String(localized: "添加 Provider")))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: String(localized: "搜索厂商、ID 或中转…"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
            }
        }
    }

    // MARK: - 预设选择
    private var presetsList: some View {
        VStack(spacing: 16) {
            if !partners.isEmpty {
                partnerGrid
            }
            if !vendors.isEmpty {
                presetGroup(title: String(localized: "Vendors"), hint: String(localized: "厂商直连"), list: vendors)
            }
            if !relays.isEmpty {
                presetGroup(title: String(localized: "Relays"), hint: String(localized: "聚合与中转"), list: relays)
            }
            if !localPresets.isEmpty {
                presetGroup(title: String(localized: "Local"), hint: String(localized: "本机服务"), list: localPresets)
            }
            if !remotePresets.isEmpty {
                presetGroup(title: String(localized: "Remote magpie"), hint: String(localized: "另一台 magpie"), list: remotePresets)
            }

            Button {
                selectCustom()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(MagpieTheme.accentSoft)
                            .frame(width: 38, height: 38)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(MagpieTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "自定义 Provider"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Text(String(localized: "任意 OpenAI / Responses / Anthropic / Gemini 兼容端点"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
                .magpieCard()
            }
            .buttonStyle(.plain)

            subscriptionCard

            if !viewModel.plugins.isEmpty {
                pluginSubsCard
            }
        }
        .sheet(isPresented: $showingSignIn) {
            ProviderSignInSheet()
                .environment(viewModel)
        }
        .sheet(item: $pluginSignIn) { plugin in
            PluginSignInSheet(plugin: plugin)
                .environment(viewModel)
        }
    }

    /// 插件提供的订阅（官方 Add 面板的 Plugins 分组）。
    private var pluginSubsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "插件订阅"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Spacer()
                Text(String(localized: "由插件提供登录"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            .padding(.horizontal, 4)

            LazyVStack(spacing: 8) {
                ForEach(viewModel.plugins) { plugin in
                    Button {
                        pluginSignIn = plugin
                    } label: {
                        HStack(spacing: 12) {
                            MagpieIconView(
                                icon: plugin.icon ?? plugin.id,
                                name: plugin.displayName,
                                size: 32,
                                cornerRadius: 7
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(plugin.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(MagpieTheme.textPrimary)
                                        .lineLimit(1)
                                    if plugin.isSignedIn {
                                        MagpieStatusChip(text: String(localized: "已登录"), color: MagpieTheme.green)
                                    }
                                }
                                Text(plugin.spec)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(MagpieTheme.textMuted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if let models = plugin.models, models > 0 {
                                Text("\(models)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                        .magpieCard(padding: 12)
                    }
                    .buttonStyle(MagpiePressableStyle())
                }
            }
        }
    }

    /// 订阅账号：官方 Add 面板的「登录已有订阅」入口。
    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "订阅账号"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Spacer()
                Text(String(localized: "Claude / ChatGPT / Copilot"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            .padding(.horizontal, 4)

            Button {
                showingSignIn = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(MagpieTheme.greenSoft)
                            .frame(width: 38, height: 38)
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MagpieTheme.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "登录订阅账号"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Text(String(localized: "把 Claude Code、ChatGPT 或 Copilot 的登录变成可用 Provider"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                            .lineLimit(2)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
                .magpieCard()
            }
            .buttonStyle(MagpiePressableStyle())
        }
    }

    // MARK: - 合作方网格（官方 Add 的 Partner 卡片）
    private var partnerGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Partners")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Spacer()
                Text(String(localized: "官方合作与赞助"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(partners) { preset in
                    Button {
                        selectPreset(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 8) {
                                MagpieIconView(
                                    icon: preset.icon ?? preset.id,
                                    name: preset.name,
                                    size: 32,
                                    cornerRadius: 8
                                )
                                Spacer(minLength: 0)
                                if preset.new == true {
                                    MagpieStatusChip(text: "NEW", color: MagpieTheme.green)
                                }
                                if preset.added == true {
                                    Text(String(localized: "已添加"))
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(MagpieTheme.textMuted)
                                }
                            }

                            Text(preset.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MagpieTheme.textPrimary)
                                .lineLimit(1)

                            if let note = preset.localizedNote, !note.isEmpty {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundStyle(MagpieTheme.textMuted)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .magpieCard(padding: 12)
                    }
                    .buttonStyle(MagpiePressableStyle())
                }
            }
        }
    }

    private func presetGroup(title: String, hint: String, list: [PresetDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Spacer()
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            .padding(.horizontal, 4)

            LazyVStack(spacing: 8) {
                ForEach(list) { preset in
                    Button {
                        selectPreset(preset)
                    } label: {
                        HStack(spacing: 12) {
                            MagpieIconView(icon: preset.icon ?? preset.id, name: preset.name, size: 32, cornerRadius: 7)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(preset.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(MagpieTheme.textPrimary)
                                        .lineLimit(1)

                                    if preset.sponsored == true {
                                        MagpieStatusChip(text: "PARTNER", color: MagpieTheme.accent)
                                    }
                                    if preset.new == true {
                                        MagpieStatusChip(text: "NEW", color: MagpieTheme.green)
                                    }
                                    if preset.vertex == true {
                                        MagpieStatusChip(text: "VERTEX", color: MagpieTheme.purple)
                                    }
                                }

                                if let note = preset.localizedNote, !note.isEmpty {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(MagpieTheme.textMuted)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if preset.added == true {
                                Text(String(localized: "已添加"))
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MagpieTheme.pill)
                                    .foregroundStyle(MagpieTheme.textMuted)
                                    .clipShape(Capsule())
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                        .magpieCard(padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 配置表单
    private var configureForm: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                MagpieIconView(
                    icon: selectedPreset?.icon ?? selectedPreset?.id ?? "generic",
                    name: selectedPreset?.name ?? (customName.isEmpty ? "custom" : customName),
                    size: 42,
                    cornerRadius: 9
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPreset?.displayName ?? (customName.isEmpty ? String(localized: "自定义 Provider") : customName))
                        .font(.headline)
                        .foregroundStyle(MagpieTheme.textPrimary)

                    Text(selectedPreset?.id ?? (customID.isEmpty ? "custom-id" : slugify(customID)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                }

                Spacer()

                Button(String(localized: "重新选择")) {
                    selectedPreset = nil
                    selectedRegion = nil
                    isCustom = false
                    submitError = nil
                    detections = []
                    testError = nil
                    fetchedModels = []
                    fetchError = nil
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(MagpieTheme.accent)
            }
            .magpieCard()

            VStack(alignment: .leading, spacing: 14) {
                if isCustom {
                    fieldBlock(title: String(localized: "提供商标识 (ID)")) {
                        TextField("my-provider", text: $customID)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    fieldBlock(title: String(localized: "展示名称")) {
                        TextField("My Provider", text: $customName)
                    }

                    fieldBlock(title: String(localized: "Base URL")) {
                        TextField("https://api.example.com/v1", text: $customHost)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    fieldBlock(title: String(localized: "API 类型")) {
                        Picker("", selection: $customAPI) {
                            Text("OpenAI Chat").tag("chat")
                            Text("Responses").tag("responses")
                            Text("Anthropic Messages").tag("anthropic")
                            Text("Gemini").tag("gemini")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                if !regions.isEmpty {
                    fieldBlock(title: selectedPreset?.regionLabel ?? String(localized: "区域 / 套餐")) {
                        Picker("", selection: regionSelection) {
                            ForEach(regions) { region in
                                Text(region.label).tag(region.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                if let endpoint = selectedPreset?.endpoint, !endpoint.isEmpty {
                    fieldBlock(title: String(localized: "自定义端点 URL")) {
                        TextField(selectedPreset?.endpointHint ?? endpoint, text: $customHost)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                }

                if selectedPreset?.vertex == true {
                    fieldBlock(title: String(localized: "Google Cloud 项目")) {
                        TextField("my-gcp-project", text: $vertexProject)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    fieldBlock(title: String(localized: "项目区域 (Location)")) {
                        TextField("global", text: $vertexLocation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    Text(String(localized: "Vertex AI 的凭据由 magpie 所在主机上的 Google 凭据提供；这里只填写项目与区域。"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                        .padding(.horizontal, 2)
                }

                fieldBlock(title: keyFieldTitle) {
                    HStack {
                        if isKeyVisible {
                            TextField(keyPlaceholder, text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField(keyPlaceholder, text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                    }
                }

                if let keysUrl = keyURL, let url = URL(string: keysUrl) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text(String(localized: "获取 API Key"))
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MagpieTheme.accent)
                    }
                    .padding(.top, -6)
                }

                Divider().background(MagpieTheme.borderSubtle)

                Toggle(String(localized: "允许联网搜索 (Searches)"), isOn: $allowSearches)
                    .font(.subheadline)
                    .tint(MagpieTheme.green)

                Toggle(String(localized: "免脱敏发送 (Unredacted)"), isOn: $unredacted)
                    .font(.subheadline)
                    .tint(MagpieTheme.green)
            }
            .magpieCard()

            // 检测
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "保存前检测"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Text(String(localized: "向每个 API 端点发送最小请求，确认协议与连通性"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        detect()
                    } label: {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "检测连接"))
                        }
                    }
                    .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.accent))
                    .disabled(isTesting || !canTest)
                }

                if let testError {
                    Text(testError)
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.red)
                        .textSelection(.enabled)
                }

                if !detections.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                            detectionRow(detection)
                            if index < detections.count - 1 {
                                Divider()
                                    .background(MagpieTheme.borderSubtle)
                                    .padding(.leading, 10)
                            }
                        }
                    }
                }
            }
            .magpieCard()

            // 保存前获取厂商模型目录（官方 Add 的 Fetch models）
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "获取模型列表"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Text(String(localized: "用当前填写的 Key 与端点向厂商拉取目录，不保存任何配置"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        fetchModels()
                    } label: {
                        if isFetchingModels {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "获取模型"))
                        }
                    }
                    .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.purple))
                    .disabled(isFetchingModels || !canTest)
                }

                if let fetchError {
                    Text(fetchError)
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.red)
                        .textSelection(.enabled)
                }

                if !fetchedModels.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(MagpieTheme.green)
                        Text(String(localized: "厂商返回 \(fetchedModels.count) 个模型"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Spacer()
                    }
                    Text(fetchedModels.prefix(16).map(\.displayName).joined(separator: " · "))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textSecondary)
                        .lineLimit(4)
                }
            }
            .magpieCard()

            if let error = submitError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(MagpieTheme.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .magpieCard()
            }

            Button {
                saveProvider()
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(String(localized: "保存并启用"))
                            .font(.subheadline.weight(.bold))
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.accent))
            .disabled(isSubmitting || !canSave)
        }
    }

    // MARK: - 行
    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MagpieTheme.textSecondary)
            content()
                .font(.subheadline)
                .padding(10)
                .background(MagpieTheme.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func detectionRow(_ detection: ProviderDetectionDTO) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: detection.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(detection.succeeded ? MagpieTheme.green : MagpieTheme.red)

                Text(detection.protocolLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)

                if detection.succeeded {
                    Text("\(Int(detection.ms ?? 0))ms")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MagpieTheme.green)
                } else if let status = detection.status, status > 0 {
                    Text("HTTP \(status)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MagpieTheme.red)
                }

                Spacer()

                if isCustom, detection.succeeded, let base = detection.base, !base.isEmpty {
                    Button(String(localized: "使用")) {
                        customHost = base
                        customAPI = detection.protocolName
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(MagpieTheme.accent)
                }
            }

            if let base = detection.base, !base.isEmpty {
                Text(base)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .textSelection(.enabled)
            }

            if let error = detection.error, !error.isEmpty {
                Text(error)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.red)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - 选择
    private var regionSelection: Binding<String> {
        Binding(
            get: { selectedRegion?.id ?? regions.first?.id ?? "" },
            set: { id in
                selectedRegion = regions.first { $0.id == id }
            }
        )
    }

    private var keyFieldTitle: String {
        (selectedPreset?.noKey == true) ? String(localized: "API Key（可选）") : String(localized: "API Key")
    }

    private var keyPlaceholder: String {
        selectedPreset?.keyHint ?? String(localized: "输入 API Key…")
    }

    private var keyURL: String? {
        selectedRegion?.keysUrl ?? selectedPreset?.keysUrl
    }

    private var canTest: Bool {
        if isCustom {
            return !customHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedPreset != nil
    }

    private var canSave: Bool {
        if isCustom {
            return !slugify(customID).isEmpty
                && !customHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard let preset = selectedPreset else { return false }
        if preset.noKey != true && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if (preset.endpoint != nil || preset.endpointNeeded != nil)
            && customHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }

    private func selectPreset(_ preset: PresetDTO) {
        selectedPreset = preset
        selectedRegion = preset.regions?.first
        isCustom = false
        customHost = ""
        apiKey = ""
        submitError = nil
        detections = []
        testError = nil
        allowSearches = false
        unredacted = false
        vertexProject = ""
        vertexLocation = "global"
        fetchedModels = []
        fetchError = nil
    }

    private func selectCustom() {
        selectedPreset = nil
        selectedRegion = nil
        isCustom = true
        customID = ""
        customName = ""
        customHost = ""
        apiKey = ""
        customAPI = "chat"
        submitError = nil
        detections = []
        testError = nil
        vertexProject = ""
        vertexLocation = "global"
        fetchedModels = []
        fetchError = nil
    }

    // MARK: - 检测
    private func detect() {
        guard let client = app.client else { return }
        isTesting = true
        testError = nil
        detections = []

        let request: ProviderDetectRequest
        if let preset = selectedPreset {
            let endpoint = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let usesEndpoint = preset.endpoint != nil
            request = ProviderDetectRequest(
                id: "",
                name: preset.displayName,
                preset: preset.id,
                key: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                chat: usesEndpoint ? (endpoint.isEmpty ? nil : endpoint) : (selectedRegion?.chat ?? preset.chat),
                responses: usesEndpoint ? (endpoint.isEmpty ? nil : endpoint) : (selectedRegion?.responses ?? preset.responses),
                anthropic: usesEndpoint ? (endpoint.isEmpty ? nil : endpoint) : (selectedRegion?.anthropic ?? preset.anthropic),
                gemini: nil,
                base: nil,
                isNew: true
            )
        } else {
            request = ProviderDetectRequest(
                id: "",
                name: customName.isEmpty ? "custom" : customName,
                preset: nil,
                key: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                chat: nil,
                responses: nil,
                anthropic: nil,
                gemini: nil,
                base: customHost.trimmingCharacters(in: .whitespacesAndNewlines),
                isNew: true
            )
        }

        Task {
            defer { isTesting = false }
            if let response = await viewModel.detect(client: client, request: request) {
                detections = response.results
                if detections.isEmpty {
                    testError = String(localized: "没有可检测的端点。")
                }
            } else {
                testError = viewModel.errorMessage ?? String(localized: "检测失败")
            }
        }
    }

    // MARK: - 保存
    private func saveProvider() {
        guard let client = app.client else { return }
        isSubmitting = true
        submitError = nil

        let body = buildSaveRequest(isNew: true)

        Task {
            defer { isSubmitting = false }
            if await viewModel.save(client: client, request: body) {
                dismiss()
            } else {
                submitError = viewModel.errorMessage ?? String(localized: "保存失败")
            }
        }
    }

    /// 表单当前取值的保存请求；Add 与「保存前获取模型」共用。
    private func buildSaveRequest(isNew: Bool) -> ProviderSaveRequest {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let vertex = selectedPreset?.vertex == true
            ? ProviderDTO.VertexDTO(
                project: vertexProject.trimmingCharacters(in: .whitespacesAndNewlines),
                location: vertexLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            : nil

        if let preset = selectedPreset {
            // 预设的端点由服务端从 preset 展开；只有用户选了区域/端点时才显式发送。
            let endpoint = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
            var chat = selectedRegion?.chat
            var responses = selectedRegion?.responses
            var anthropic = selectedRegion?.anthropic

            if preset.endpoint != nil, !endpoint.isEmpty {
                if preset.chat != nil { chat = endpoint }
                if preset.responses != nil { responses = endpoint }
                if preset.anthropic != nil { anthropic = endpoint }
            }

            return ProviderSaveRequest(
                id: preset.id,
                name: preset.displayName,
                preset: preset.id,
                key: key.isEmpty ? nil : key,
                chat: chat,
                responses: responses,
                anthropic: anthropic,
                gemini: nil,
                baseAPI: nil,
                isNew: isNew,
                searches: allowSearches ? true : nil,
                unredacted: unredacted ? true : nil,
                vertex: vertex
            )
        }

        let host = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = slugify(customID)
        var chat: String?
        var responses: String?
        var anthropic: String?
        var gemini: String?

        switch customAPI {
        case "responses": responses = host
        case "anthropic": anthropic = host
        case "gemini": gemini = host
        default: chat = host
        }

        return ProviderSaveRequest(
            id: id,
            name: customName.isEmpty ? id : customName,
            preset: nil,
            key: key.isEmpty ? nil : key,
            chat: chat,
            responses: responses,
            anthropic: anthropic,
            gemini: gemini,
            baseAPI: customAPI == "chat" ? nil : customAPI,
            isNew: isNew,
            searches: allowSearches ? true : nil,
            unredacted: unredacted ? true : nil,
            vertex: vertex
        )
    }

    /// 官方要求 Provider ID 只能是小写字母、数字和短横线。
    private func slugify(_ value: String) -> String {
        let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        var result = ""
        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if scalar == " " || scalar == "_" || scalar == "/" {
                result.append("-")
            }
        }
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }

    // MARK: - 保存前获取模型
    private func fetchModels() {
        guard let client = app.client else { return }
        isFetchingModels = true
        fetchError = nil
        fetchedModels = []
        Task {
            defer { isFetchingModels = false }
            if let response = await viewModel.previewModels(client: client, request: buildSaveRequest(isNew: true)) {
                fetchedModels = response.models ?? []
                if fetchedModels.isEmpty {
                    fetchError = String(localized: "厂商没有返回任何模型。")
                }
            } else {
                fetchError = viewModel.errorMessage ?? String(localized: "获取模型失败")
            }
        }
    }
}
