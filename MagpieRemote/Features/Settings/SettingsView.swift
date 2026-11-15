import SwiftUI
import UIKit

/// Settings：与官方 Web 端一致的设置中心，但采用原生 Apple 分组卡片布局。
/// 所有开关都直接写入服务器的 `/api/settings`，并回读最新状态。
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var viewModel = SettingsViewModel()
    @State private var showingDisconnect = false
    @State private var showingBackupSheet = false
    @State private var backupPath: String?
    @State private var backupError: String?
    @State private var showingDavsync = false
    @State private var davsyncStatus: JSONValue?
    @State private var davsyncText = ""
    @State private var davsyncResult: String?
    @State private var otelEndpointDraft = ""
    @State private var otelHeadersDraft = ""
    @State private var otelPrimed = false

    private var settings: SettingsDTO? { viewModel.settings ?? app.state?.settings }

    private var cacheTTLValue: String {
        settings?.claudeCacheKnobs?.first { $0.knob == "cache_ttl" }?.value ?? ""
    }

    var body: some View {
        MagpieNavigationContainer {
            ScrollView {
                VStack(spacing: 18) {
                    serverHero
                    appearanceSection
                    usageSection
                    networkSection
                    modelsSection
                    privacySection
                    observabilitySection
                    backupSection
                    davsyncSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "Settings"))
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let client = app.client, viewModel.settings == nil {
                    await viewModel.load(client: client)
                }
            }
            .refreshable {
                if let client = app.client { await viewModel.load(client: client) }
            }
            .overlay {
                if viewModel.isLoading && viewModel.settings == nil {
                    ProgressView(String(localized: "读取设置…"))
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isSaving {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .alert(String(localized: "断开当前连接？"), isPresented: $showingDisconnect) {
                Button(String(localized: "断开"), role: .destructive) {
                    app.disconnect()
                }
                Button(String(localized: "取消"), role: .cancel) {}
            } message: {
                Text(String(localized: "断开后需要重新选择服务器并输入 Web Key。"))
            }
            .sheet(isPresented: $showingBackupSheet) {
                BackupExportSheet(
                    onExport: { passphrase, keys, signIns in
                        guard let client = app.client else { return nil }
                        let result = await viewModel.exportBackup(
                            client: client,
                            passphrase: passphrase,
                            includeKeys: keys,
                            includeSignIns: signIns
                        )
                        if let result {
                            backupPath = result.path
                        } else {
                            backupError = viewModel.errorMessage ?? String(localized: "导出失败")
                        }
                        return result
                    }
                )
            }
            .sheet(isPresented: $showingDavsync) {
                DavsyncSheet(
                    status: davsyncStatus,
                    onSave: { url, user, pass in
                        guard let client = app.client else { return false }
                        let body: [String: Any] = ["url": url, "user": user, "pass": pass]
                        let result = await viewModel.davsync(client: client, action: "save", body: body)
                        davsyncStatus = result
                        return result != nil
                    },
                    onSync: {
                        guard let client = app.client else { return false }
                        let result = await viewModel.davsync(client: client, action: "now")
                        davsyncStatus = result
                        return result != nil
                    },
                    onOff: {
                        guard let client = app.client else { return false }
                        let result = await viewModel.davsync(client: client, action: "off")
                        davsyncStatus = result
                        return result != nil
                    }
                )
            }
            .alert(
                String(localized: "备份已导出"),
                isPresented: Binding(
                    get: { backupPath != nil },
                    set: { if !$0 { backupPath = nil } }
                )
            ) {
                Button(String(localized: "复制路径")) {
                    if let path = backupPath { UIPasteboard.general.string = path }
                    backupPath = nil
                }
                Button(String(localized: "完成"), role: .cancel) { backupPath = nil }
            } message: {
                Text(backupPath ?? "")
            }
        }
    }

    // MARK: - 服务器
    private var serverHero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MagpieTheme.accent, Color(hex: "8b5cf6").opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                        .shadow(color: MagpieTheme.accent.opacity(0.32), radius: 12, x: 0, y: 6)
                    Image(systemName: "bird.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(app.activeName.isEmpty ? String(localized: "服务器") : app.activeName)
                            .font(.headline)
                            .foregroundStyle(MagpieTheme.textPrimary)
                        MagpieStatusChip(
                            text: app.isConnected ? String(localized: "已连接") : String(localized: "离线"),
                            color: app.isConnected ? MagpieTheme.green : MagpieTheme.amber
                        )
                    }

                    if let url = app.activeURL {
                        Text(url.absoluteString)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(MagpieTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
            }

            Divider().background(MagpieTheme.borderSubtle)

            HStack(spacing: 0) {
                serverStat(String(localized: "版本"), settings?.version ?? "—")
                Spacer()
                serverStat(String(localized: "网关"), settings?.gateway ?? "—")
            }
        }
        .magpieCard()
    }

    private func serverStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(MagpieTheme.textSecondary)
                .lineLimit(1)
        }
    }

    // MARK: - 外观
    private var appearanceSection: some View {
        settingsSection(String(localized: "外观与语言"), icon: "paintbrush.fill", tint: MagpieTheme.accent) {
            themeRow
            rowDivider
            pickerRow(
                String(localized: "界面语言"),
                subtitle: String(localized: "服务端 Web UI 的显示语言"),
                icon: "globe",
                tint: MagpieTheme.cyan,
                selection: stringBinding(key: "lang", fallback: "system"),
                options: [("system", String(localized: "跟随系统")), ("zh", "简体中文"), ("en", "English")]
            )
            rowDivider
            intPickerRow(
                String(localized: "文字大小"),
                subtitle: String(localized: "缩放 Web UI 的字号"),
                icon: "textformat.size",
                tint: MagpieTheme.amber,
                selection: intBinding(key: "textSize", fallback: 100),
                options: [(90, String(localized: "紧凑")), (100, String(localized: "标准")), (110, String(localized: "较大")), (120, String(localized: "特大"))]
            )
        }
    }

    private var themeRow: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                settingsGlyph("circle.lefthalf.filled", tint: MagpieTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "主题外观"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(String(localized: "跟随系统、浅色或深色"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
                Spacer()
            }

            Picker("", selection: stringBinding(key: "theme", fallback: "system")) {
                Text(String(localized: "跟随系统")).tag("system")
                Text(String(localized: "浅色")).tag("light")
                Text(String(localized: "深色")).tag("dark")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 用量
    private var usageSection: some View {
        settingsSection(String(localized: "用量与货币"), icon: "chart.pie.fill", tint: MagpieTheme.green) {
            pickerRow(
                String(localized: "计价货币"),
                subtitle: String(localized: "费用与总额的显示货币"),
                icon: "dollarsign.circle.fill",
                tint: MagpieTheme.green,
                selection: stringBinding(key: "currency", fallback: "usd"),
                options: [("usd", String(localized: "美元 $")), ("cny", String(localized: "人民币 ¥")), ("provider", String(localized: "按提供方"))]
            )
            rowDivider
            intPickerRow(
                String(localized: "一天从几点开始"),
                subtitle: String(localized: "用量图表与每日额度的切分时间"),
                icon: "clock.fill",
                tint: MagpieTheme.cyan,
                selection: intBinding(key: "dayStart", fallback: 0),
                options: (0...6).map { ($0, String(format: "%02d:00", $0)) }
            )
            rowDivider
            toggleRow(
                String(localized: "显示剩余额度"),
                subtitle: String(localized: "配额显示为剩余量而非已用量"),
                icon: "gauge.with.dots.needle.33percent",
                tint: MagpieTheme.amber,
                isOn: boolBinding(key: "quotaLeft", fallback: false)
            )
            rowDivider
            toggleRow(
                String(localized: "中文数字单位"),
                subtitle: String(localized: "使用万 / 亿显示较大的计数"),
                icon: "character.book.closed.fill",
                tint: MagpieTheme.purple,
                isOn: boolBinding(key: "chineseUnits", fallback: false)
            )
        }
    }

    // MARK: - 网络
    private var networkSection: some View {
        settingsSection(String(localized: "网络与共享"), icon: "network", tint: MagpieTheme.cyan) {
            toggleRow(
                String(localized: "局域网共享"),
                subtitle: String(localized: "允许局域网设备通过 Gateway Key 访问"),
                icon: "wifi.router.fill",
                tint: MagpieTheme.cyan,
                isOn: boolBinding(key: "lan", fallback: false)
            )
            rowDivider
            toggleRow(
                String(localized: "记录网关对话"),
                subtitle: String(localized: "为 Sessions 与用量统计保留请求内容"),
                icon: "bubble.left.and.text.bubble.right.fill",
                tint: MagpieTheme.accent,
                isOn: boolBinding(key: "gatewayConversations", fallback: true)
            )
            rowDivider
            toggleRow(
                String(localized: "保持系统唤醒"),
                subtitle: String(localized: "magpie 运行时阻止机器休眠，避免网关中断"),
                icon: "cup.and.saucer.fill",
                tint: MagpieTheme.green,
                isOn: boolBinding(key: "\u{6B}\u{65}\u{65}\u{70}\u{41}\u{77}\u{61}\u{6B}\u{65}", fallback: false)
            )
            if let keyID = settings?.lanKeyId, !keyID.isEmpty {
                rowDivider
                copyRow(
                    String(localized: "LAN 默认密钥 ID"),
                    value: keyID,
                    icon: "key.fill",
                    tint: MagpieTheme.amber
                )
            }
        }
    }

    // MARK: - 模型
    private var modelsSection: some View {
        settingsSection(String(localized: "模型与优化"), icon: "cpu.fill", tint: MagpieTheme.purple) {
            if let vision = settings?.visionAutoModel, !vision.isEmpty {
                infoRow(
                    String(localized: "默认视觉模型"),
                    value: vision,
                    icon: "photo.on.rectangle.angled",
                    tint: MagpieTheme.purple
                )
                rowDivider
            }

            toggleRow(
                String(localized: "Claude 提示词缓存"),
                subtitle: String(localized: "保持缓存活跃以降低 Token 费用"),
                icon: "bolt.horizontal.circle.fill",
                tint: MagpieTheme.amber,
                isOn: boolBinding(key: "claudeCache", fallback: true)
            )
            rowDivider
            pickerRow(
                String(localized: "Claude 缓存时长"),
                subtitle: String(localized: "提示词缓存 TTL（cache_ttl）"),
                icon: "clock.fill",
                tint: MagpieTheme.amber,
                selection: Binding(
                    get: { cacheTTLValue },
                    set: { value in
                        guard let client = app.client else { return }
                        Task {
                            await viewModel.setClaudeCache(
                                client: client,
                                knob: "cache_ttl",
                                value: value
                            )
                        }
                    }
                ),
                options: [
                    ("", String(localized: "默认（5 分钟）")),
                    ("1h", String(localized: "1 小时"))
                ]
            )
            rowDivider
            toggleRow(
                String(localized: "保留 Claude 署名"),
                subtitle: String(localized: "在提交与 PR 中保留自动署名"),
                icon: "signature",
                tint: MagpieTheme.textSecondary,
                isOn: Binding(
                    get: { (settings?.claudeAttributionRaw ?? "on") != "off" },
                    set: { update("claudeAttribution", $0 ? "on" : "off") }
                )
            )
            rowDivider
            toggleRow(
                String(localized: "完整上下文窗口"),
                subtitle: String(localized: "告知 Agent 模型的完整窗口，而不是可用工作窗口"),
                icon: "rectangle.expand.vertical",
                tint: MagpieTheme.cyan,
                isOn: boolBinding(key: "fullContext", fallback: false)
            )
            rowDivider
            toggleRow(
                String(localized: "Codex 多 Agent V1"),
                subtitle: String(localized: "Codex 的 OpenAI 模型声明 multi-agent V1"),
                icon: "person.3.fill",
                tint: MagpieTheme.purple,
                isOn: boolBinding(key: "codexAgentsV1", fallback: false)
            )
        }
    }

    // MARK: - 隐私
    private var privacySection: some View {
        settingsSection(String(localized: "隐私与脱敏"), icon: "shield.lefthalf.filled", tint: MagpieTheme.green) {
            toggleRow(
                String(localized: "启用脱敏"),
                subtitle: String(localized: "请求离开设备前替换凭证与密钥"),
                icon: "key.slash.fill",
                tint: MagpieTheme.green,
                isOn: boolBinding(key: "redact", fallback: false)
            )
            rowDivider
            toggleRow(
                String(localized: "个人信息 (PII)"),
                subtitle: String(localized: "邮箱、电话、证件与银行卡号"),
                icon: "person.text.rectangle.fill",
                tint: MagpieTheme.cyan,
                isOn: boolBinding(key: "redactPersonal", fallback: false)
            )
            rowDivider
            toggleRow(
                String(localized: "保持密钥形状"),
                subtitle: String(localized: "使用同格式的假密钥替换"),
                icon: "signature",
                tint: MagpieTheme.amber,
                isOn: boolBinding(key: "redactShape", fallback: false)
            )
            rowDivider
            toggleRow(
                String(localized: "本地模型识别"),
                subtitle: String(localized: "识别规则找不到的姓名与地址"),
                icon: "brain.head.profile",
                tint: MagpieTheme.purple,
                isOn: boolBinding(key: "redactModel", fallback: false)
            )
        }
    }

    // MARK: - 可观测性（OTLP）
    private var observabilitySection: some View {
        let otel = settings?.otel ?? OtelSettingsDTO()
        let contentMode = !(otel.bodies ?? false)
            ? "metadata"
            : ((otel.bodiesWhole ?? false) ? "full" : "limited")
        return settingsSection(String(localized: "可观测性"), icon: "waveform.path.ecg", tint: MagpieTheme.cyan) {
            toggleRow(
                String(localized: "OTLP 导出"),
                subtitle: String(localized: "把网关请求元数据发送到你的采集器；账号凭证始终留在本机"),
                icon: "paperplane.fill",
                tint: MagpieTheme.cyan,
                isOn: Binding(
                    get: { otel.enabled ?? false },
                    set: { setOtel(enabled: $0) }
                )
            )
            rowDivider
            otelFieldRow(
                String(localized: "OTLP 端点"),
                subtitle: String(localized: "采集器的基础地址，或 Langfuse 的 /api/public/otel 端点"),
                icon: "link",
                tint: MagpieTheme.cyan,
                placeholder: "http://localhost:4318",
                text: $otelEndpointDraft,
                isSecret: false
            ) {
                setOtel(endpoint: otelEndpointDraft.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            rowDivider
            otelFieldRow(
                String(localized: "OTLP 请求头"),
                subtitle: String(localized: "逗号分隔的 name=value；值里的空格与逗号用百分号编码"),
                icon: "list.bullet.rectangle",
                tint: MagpieTheme.amber,
                placeholder: "Authorization=Bearer%20token",
                text: $otelHeadersDraft,
                isSecret: true
            ) {
                commitOtelHeaders()
            }
            rowDivider
            toggleRow(
                String(localized: "导出指标"),
                subtitle: String(localized: "同时发送时长与 Token 直方图；Langfuse 等仅接受 Trace 的服务请关闭"),
                icon: "chart.bar.xaxis",
                tint: MagpieTheme.green,
                isOn: Binding(
                    get: { otel.metrics ?? false },
                    set: { setOtel(metrics: $0) }
                )
            )
            rowDivider
            toggleRow(
                String(localized: "追踪 Agent 会话"),
                subtitle: String(localized: "读取本机各 Agent 的会话事件，包括未经 magpie 的调用"),
                icon: "point.3.connected.trianglepath.dotted",
                tint: MagpieTheme.purple,
                isOn: Binding(
                    get: { otel.sessions ?? false },
                    set: { setOtel(sessions: $0) }
                )
            )
            rowDivider
            pickerRow(
                String(localized: "Trace 内容"),
                subtitle: String(localized: "是否随 Trace 导出请求与回复正文"),
                icon: "text.alignleft",
                tint: MagpieTheme.cyan,
                selection: Binding(
                    get: { contentMode },
                    set: { mode in
                        switch mode {
                        case "full": setOtel(bodies: true, bodiesWhole: true)
                        case "limited": setOtel(bodies: true, bodiesWhole: false)
                        default: setOtel(bodies: false, bodiesWhole: false)
                        }
                    }
                ),
                options: [
                    ("metadata", String(localized: "仅元数据")),
                    ("limited", String(localized: "最多 256 KB")),
                    ("full", String(localized: "完整内容"))
                ]
            )
        }
        .onAppear {
            guard !otelPrimed else { return }
            otelPrimed = true
            otelEndpointDraft = otel.endpoint ?? ""
            otelHeadersDraft = (otel.headers ?? [:])
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
                .sorted()
                .joined(separator: ",")
        }
    }

    /// 保存 OTel 配置：只覆盖传入的字段，其余保持服务端原值。
    private func setOtel(
        enabled: Bool? = nil,
        endpoint: String? = nil,
        headers: [String: String]? = nil,
        metrics: Bool? = nil,
        sessions: Bool? = nil,
        bodies: Bool? = nil,
        bodiesWhole: Bool? = nil
    ) {
        guard let client = app.client else { return }
        var next = settings?.otel ?? OtelSettingsDTO()
        if let enabled { next.enabled = enabled }
        if let endpoint { next.endpoint = endpoint }
        if let headers { next.headers = headers }
        if let metrics { next.metrics = metrics }
        if let sessions { next.sessions = sessions }
        if let bodies { next.bodies = bodies }
        if let bodiesWhole { next.bodiesWhole = bodiesWhole }
        Task { await viewModel.update(client: client, key: "otel", value: next) }
    }

    /// 解析 `name=value,name2=value2` 形式的请求头并保存。
    private func commitOtelHeaders() {
        let raw = otelHeadersDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            setOtel(headers: [:])
            return
        }
        var values: [String: String] = [:]
        for part in raw.split(separator: ",") where !part.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let index = part.firstIndex(of: "="), index != part.startIndex else {
                return
            }
            let name = part[..<index].trimmingCharacters(in: .whitespaces)
            let value = part[part.index(after: index)...].trimmingCharacters(in: .whitespaces)
            values[name] = value.removingPercentEncoding ?? value
        }
        setOtel(headers: values)
    }

    // MARK: - 备份
    private var backupSection: some View {
        settingsSection(String(localized: "备份与恢复"), icon: "externaldrive.fill", tint: MagpieTheme.cyan) {
            Button {
                showingBackupSheet = true
            } label: {
                HStack(spacing: 12) {
                    settingsGlyph("square.and.arrow.up.on.square.fill", tint: MagpieTheme.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "导出备份到服务器…"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Text(String(localized: "打包 Provider、Profiles、Agents 与库设置，写入 magpie 所在机器的 Downloads"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let backupError {
                rowDivider
                Text(backupError)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - WebDAV 同步
    private var davsyncSection: some View {
        settingsSection(String(localized: "WebDAV 同步"), icon: "arrow.triangle.2.circlepath", tint: MagpieTheme.purple) {
            Button {
                loadDavsync()
                showingDavsync = true
            } label: {
                HStack(spacing: 12) {
                    settingsGlyph("arrow.triangle.2.circlepath", tint: MagpieTheme.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "WebDAV 同步设置…"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MagpieTheme.textPrimary)
                        Text(String(localized: "把 Provider、Profiles 等备份到 WebDAV 服务器，并在多台电脑间同步"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if let status = davsyncStatus {
                        let error = status.string("error")
                        MagpieStatusChip(
                            text: error?.isEmpty == false ? String(localized: "有错误") : String(localized: "已配置"),
                            color: error?.isEmpty == false ? MagpieTheme.red : MagpieTheme.green
                        )
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let davsyncResult {
                rowDivider
                Text(davsyncResult)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }

    private func loadDavsync() {
        guard let client = app.client else { return }
        Task {
            if let status = await viewModel.davsync(client: client, action: "now") {
                davsyncStatus = status
                davsyncResult = status.string("error") ?? String(localized: "同步完成")
            }
        }
    }

    // MARK: - 关于
    private var aboutSection: some View {
        settingsSection(String(localized: "关于"), icon: "info.circle.fill", tint: MagpieTheme.textSecondary) {
            infoRow(
                String(localized: "客户端"),
                value: "Magpie Remote \(appVersion)",
                icon: "iphone",
                tint: MagpieTheme.accent
            )
            rowDivider
            infoRow(
                String(localized: "服务端"),
                value: settings?.version ?? "—",
                icon: "server.rack",
                tint: MagpieTheme.cyan
            )
            rowDivider
            copyRow(
                String(localized: "数据目录"),
                value: settings?.dir,
                icon: "folder.fill",
                tint: MagpieTheme.amber
            )
            rowDivider
            Button {
                showingDisconnect = true
            } label: {
                HStack(spacing: 12) {
                    settingsGlyph("rectangle.portrait.and.arrow.right", tint: MagpieTheme.red)
                    Text(String(localized: "断开当前连接"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MagpieTheme.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 分组容器
    private func settingsSection<Content: View>(
        _ title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MagpieTheme.textMuted)
                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .magpieCard(padding: 0, cornerRadius: 18)
        }
    }

    // MARK: - 行
    private func settingsGlyph(_ icon: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.13))
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private func toggleRow(
        _ title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            settingsGlyph(icon, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(MagpieTheme.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 可观测性页的文本输入行：标题 + 说明 + 独立一行的输入框。
    private func otelFieldRow(
        _ title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        placeholder: String,
        text: Binding<String>,
        isSecret: Bool,
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                settingsGlyph(icon, tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            Group {
                if isSecret {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(MagpieTheme.pill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .submitLabel(.done)
            .onSubmit(onCommit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func pickerRow(
        _ title: String,
        subtitle: String?,
        icon: String,
        tint: Color,
        selection: Binding<String>,
        options: [(String, String)]
    ) -> some View {
        HStack(spacing: 12) {
            settingsGlyph(icon, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }

            Spacer(minLength: 8)

            Picker("", selection: selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { item in
                    Text(item.element.1).tag(item.element.0)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(MagpieTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func intPickerRow(
        _ title: String,
        subtitle: String?,
        icon: String,
        tint: Color,
        selection: Binding<Int>,
        options: [(Int, String)]
    ) -> some View {
        HStack(spacing: 12) {
            settingsGlyph(icon, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }

            Spacer(minLength: 8)

            Picker("", selection: selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { item in
                    Text(item.element.1).tag(item.element.0)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(MagpieTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func infoRow(
        _ title: String,
        value: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            settingsGlyph(icon, tint: tint)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MagpieTheme.textPrimary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MagpieTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func copyRow(
        _ title: String,
        value: String?,
        icon: String,
        tint: Color
    ) -> some View {
        Button {
            guard let value, !value.isEmpty else { return }
            UIPasteboard.general.string = value
            MagpieHaptics.success()
        } label: {
            HStack(spacing: 12) {
                settingsGlyph(icon, tint: tint)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Spacer(minLength: 8)
                Text(value?.isEmpty == false ? value! : "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
                if value?.isEmpty == false {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MagpieTheme.textMuted.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rowDivider: some View {
        Divider()
            .background(MagpieTheme.borderSubtle)
            .padding(.leading, 58)
    }

    // MARK: - 绑定与写入
    private func stringBinding(key: String, fallback: String) -> Binding<String> {
        Binding(
            get: {
                let value = settings?.value(for: key) ?? ""
                return value.isEmpty ? fallback : value
            },
            set: { update(key, $0) }
        )
    }

    private func intBinding(key: String, fallback: Int) -> Binding<Int> {
        Binding(
            get: { settings?.intValue(for: key) ?? fallback },
            set: { update(key, $0) }
        )
    }

    private func boolBinding(key: String, fallback: Bool) -> Binding<Bool> {
        Binding(
            get: { settings?.boolValue(for: key) ?? fallback },
            set: { update(key, $0) }
        )
    }

    private func update<V: Encodable & Sendable>(_ key: String, _ value: V) {
        guard let client = app.client else { return }
        MagpieHaptics.light()
        Task {
            await viewModel.update(client: client, key: key, value: value)
            await app.refresh()
            MagpieHaptics.success()
        }
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }
}

// MARK: - 设置项读取
private extension SettingsDTO {
    func value(for key: String) -> String? {
        switch key {
        case "theme": return theme
        case "lang": return lang
        case "currency": return currency
        case "tray": return tray
        case "sessionTerminal": return sessionTerminal
        default: return nil
        }
    }

    func intValue(for key: String) -> Int? {
        switch key {
        case "textSize": return textSize
        case "dayStart": return dayStart
        case "updateEvery": return updateEvery
        default: return nil
        }
    }

    func boolValue(for key: String) -> Bool? {
        switch key {
        case "lan": return lan
        case "gatewayConversations": return gatewayConversations
        case "redact": return redact
        case "redactPersonal": return redactPersonal
        case "redactModel": return redactModel
        case "redactShape": return redactShape
        case "quotaLeft": return quotaLeft
        case "chineseUnits": return chineseUnits
        case "claudeCache": return claudeCacheEnabled
        case "claudeAttribution": return claudeAttributionOff.map { !$0 }
        case "fullContext": return fullContext
        case "codexAgentsV1": return codexAgentsV1
        case "\u{6B}\u{65}\u{65}\u{70}\u{41}\u{77}\u{61}\u{6B}\u{65}": return awake
        default: return nil
        }
    }
}

// MARK: - WebDAV 同步面板
private struct DavsyncSheet: View {
    let status: JSONValue?
    let onSave: (String, String, String) async -> Bool
    let onSync: () async -> Bool
    let onOff: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var user = ""
    @State private var pass = ""
    @State private var working = false
    @State private var errorMessage: String?
    @State private var primed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "WebDAV 服务器 URL"), text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField(String(localized: "用户名"), text: $user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(String(localized: "密码"), text: $pass)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "配置"))
                } footer: {
                    Text(String(localized: "保存后会立即同步一次；错误的地址或密码会立刻提示。"))
                }

                if let status {
                    Section(String(localized: "当前状态")) {
                        let last = status.string("last") ?? status.string("error")
                        LabeledContent(String(localized: "最近同步"), value: last?.isEmpty == false ? last! : "—")
                        if let when = status.string("at"), !when.isEmpty {
                            LabeledContent(String(localized: "时间"), value: when)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.red)
                    }
                }
            }
            .navigationTitle(String(localized: "WebDAV 同步"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(MagpieAuroraBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button(String(localized: "保存并同步")) {
                            save()
                        }
                        Button(String(localized: "立即同步")) {
                            sync()
                        }
                        Button(role: .destructive) {
                            off()
                        } label: {
                            Label(String(localized: "关闭同步"), systemImage: "xmark.circle")
                        }
                    } label: {
                        if working {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "同步")).fontWeight(.semibold)
                        }
                    }
                    .disabled(working)
                }
            }
            .onAppear {
                guard !primed else { return }
                primed = true
                url = status?.string("url") ?? ""
                user = status?.string("user") ?? ""
            }
        }
    }

    private func save() {
        working = true
        errorMessage = nil
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else {
            working = false
            errorMessage = String(localized: "需要填写服务器地址。")
            return
        }
        Task {
            let ok = await onSave(u, user.trimmingCharacters(in: .whitespacesAndNewlines), pass)
            working = false
            if ok { dismiss() } else { errorMessage = String(localized: "同步失败，请检查地址与凭据。") }
        }
    }

    private func sync() {
        working = true
        errorMessage = nil
        Task {
            let ok = await onSync()
            working = false
            if !ok { errorMessage = String(localized: "同步失败，请检查配置。") }
        }
    }

    private func off() {
        working = true
        errorMessage = nil
        Task {
            let ok = await onOff()
            working = false
            if ok { dismiss() } else { errorMessage = String(localized: "关闭失败。") }
        }
    }
}

// MARK: - 备份导出面板
private struct BackupExportSheet: View {
    let onExport: (String, Bool, Bool) async -> BackupExportResultDTO?

    @Environment(\.dismiss) private var dismiss
    @State private var passphrase = ""
    @State private var includeKeys = true
    @State private var includeSignIns = false
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "口令（可选，用于加密）"), text: $passphrase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(String(localized: "设置口令后，恢复备份时需要同一个口令。"))
                }

                Section {
                    Toggle(String(localized: "包含 Provider 的 Key"), isOn: $includeKeys)
                    Toggle(String(localized: "包含订阅登录（sign-ins）"), isOn: $includeSignIns)
                } footer: {
                    Text(String(localized: "备份写入 magpie 所在机器的 Downloads 文件夹；完成后会显示路径。"))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.red)
                    }
                }
            }
            .navigationTitle(String(localized: "导出备份"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(MagpieAuroraBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        export()
                    } label: {
                        if working {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "导出")).fontWeight(.semibold)
                        }
                    }
                    .disabled(working)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func export() {
        working = true
        errorMessage = nil
        Task {
            let result = await onExport(passphrase, includeKeys, includeSignIns)
            working = false
            if result != nil {
                dismiss()
            } else {
                errorMessage = String(localized: "导出失败，请稍后重试。")
            }
        }
    }
}
