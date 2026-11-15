import SwiftUI

/// Library 的「Pi 扩展」Tab：每台 Pi 的扩展与包，开关 / 复制到其他 Pi / 安装与移除。
struct LibraryPiSection: View {
    @Environment(AppModel.self) private var app
    @Environment(PiRTKViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "扩展与包：Pi 每次启动时加载。开关即时保存；包可在各 Pi 间复制。"))
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)

            if viewModel.isLoading && viewModel.piView == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if let pis = viewModel.piView?.pis, !pis.isEmpty {
                ForEach(pis) { pi in
                    piCard(pi)
                }
            } else if let error = viewModel.errorMessage {
                errorRow(error)
            } else {
                Text(String(localized: "还没有可显示的 Pi 实例。"))
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
        }
        .task {
            if viewModel.piView == nil, let client = app.client {
                await viewModel.loadPi(client: client)
            }
        }
        .refreshable {
            if let client = app.client {
                await viewModel.loadPi(client: client)
            }
        }
    }

    private func piCard(_ pi: PiDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MagpieIconView(icon: "pi", name: pi.name, size: 28, cornerRadius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pi.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    if let dir = pi.dir {
                        Text(dir)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(MagpieTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if pi.asleep == true {
                    MagpieStatusChip(text: String(localized: "WSL 未运行"), color: MagpieTheme.amber)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if let err = pi.err, !err.isEmpty {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                Divider().background(MagpieTheme.borderSubtle)

                let others = (viewModel.piView?.pis ?? []).filter { $0.id != pi.id && $0.asleep != true && $0.err == nil }
                let extensions = pi.extensions ?? []
                let packages = pi.packages ?? []

                if extensions.isEmpty && packages.isEmpty {
                    Text(String(localized: "还没有扩展或包。"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                        .padding(14)
                } else {
                    ForEach(extensions) { ext in
                        entryRow(
                            title: ext.displayName,
                            sub: ext.path,
                            on: ext.on ?? false,
                            entryID: ext.id,
                            isPackage: false,
                            piID: pi.id,
                            others: others,
                            tags: nil
                        )
                    }
                    ForEach(packages) { pkg in
                        entryRow(
                            title: pkg.name ?? pkg.source,
                            sub: pkg.source,
                            on: pkg.on ?? false,
                            entryID: pkg.source,
                            isPackage: true,
                            piID: pi.id,
                            others: others,
                            tags: [pkg.kind ?? "", pkg.installed == false ? String(localized: "未安装") : (pkg.version ?? "")],
                            filtered: pkg.filtered == true
                        )
                    }
                }
            }
        }
        .magpieCard(padding: 0)
    }

    private func entryRow(
        title: String,
        sub: String?,
        on: Bool,
        entryID: String,
        isPackage: Bool,
        piID: String,
        others: [PiDTO],
        tags: [String]?,
        filtered: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textPrimary)
                        .lineLimit(1)
                    ForEach(tags ?? [], id: \.self) { tag in
                        if !tag.isEmpty {
                            MagpieStatusChip(text: tag, color: MagpieTheme.textSecondary)
                        }
                    }
                }
                if let sub, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(MagpieTheme.textMuted)
                        .lineLimit(1)
                }
                if filtered {
                    Text(String(localized: "只加载部分包；用 pi config 修改"))
                        .font(.system(size: 9))
                        .foregroundStyle(MagpieTheme.amber)
                }
            }

            Spacer(minLength: 4)

            if !others.isEmpty {
                Menu {
                    ForEach(others) { other in
                        Button {
                            copyEntry(piID: piID, to: other.id, entryID: entryID, isPackage: isPackage)
                        } label: {
                            Text(String(localized: "复制到 \(other.name)"))
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MagpieTheme.textMuted)
                }
            }

            if isPackage {
                Button {
                    removePackage(piID: piID, source: entryID)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(MagpieTheme.red.opacity(0.85))
                }
                .buttonStyle(.plain)
            }

            Toggle("", isOn: Binding(
                get: { on },
                set: { value in
                    setEntry(piID: piID, entryID: entryID, isPackage: isPackage, on: value)
                }
            ))
            .labelsHidden()
            .tint(MagpieTheme.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func setEntry(piID: String, entryID: String, isPackage: Bool, on: Bool) {
        guard let client = app.client else { return }
        Task {
            await viewModel.setPiEntry(
                client: client,
                pi: piID,
                extensionID: isPackage ? nil : entryID,
                packageSource: isPackage ? entryID : nil,
                on: on
            )
        }
    }

    private func copyEntry(piID: String, to: String, entryID: String, isPackage: Bool) {
        guard let client = app.client else { return }
        Task {
            await viewModel.copyPiEntry(
                client: client,
                from: piID,
                to: to,
                extensionID: isPackage ? nil : entryID,
                packageSource: isPackage ? entryID : nil
            )
        }
    }

    private func removePackage(piID: String, source: String) {
        guard let client = app.client else { return }
        Task {
            await viewModel.removePiPackage(client: client, pi: piID, source: source)
        }
    }

    private func errorRow(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(MagpieTheme.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - billion-context（`/api/library/bili`）
struct LibraryBiliSection: View {
    @Environment(AppModel.self) private var app
    @Environment(PiRTKViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "billion-context 把 Agent 较早的对话折叠成摘要，让长会话保持在模型窗口内。给 Agent 打开时，magpie 会运行它自己的安装器。"))
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)

            if viewModel.isLoading && viewModel.bili == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if let bili = viewModel.bili {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        MagpieIconView(icon: "bili", name: "billion-context", size: 30, cornerRadius: 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("billion-context")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            if let version = bili.version, !version.isEmpty {
                                MagpieStatusChip(text: "v\(version)", color: MagpieTheme.accent)
                            }
                        }
                        Spacer()

                        if let path = bili.path, !path.isEmpty {
                            Text(path)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(MagpieTheme.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if bili.path == nil {
                        Divider().background(MagpieTheme.borderSubtle)
                        Text(String(localized: "billion-context 还没有安装。"))
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.textSecondary)
                            .padding(14)

                        HStack(spacing: 10) {
                            Button(String(localized: "安装 billion-context")) {
                                guard let client = app.client else { return }
                                Task { await viewModel.installBili(client: client) }
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(MagpieTheme.accent)

                            if let url = bili.url, let target = URL(string: url) {
                                Link(destination: target) {
                                    Text(String(localized: "前往官网"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MagpieTheme.accent)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }

                    if let saved = bili.saved {
                        Divider().background(MagpieTheme.borderSubtle)
                        savedSummary(saved)
                    }

                    if let listErr = bili.listErr, !listErr.isEmpty {
                        Text(listErr)
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.red)
                            .padding(14)
                    }

                    Divider().background(MagpieTheme.borderSubtle)

                    Text(String(localized: "Agent（切换后请重启对应 Agent）"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    if let agents = bili.agents, !agents.isEmpty {
                        ForEach(agents) { agent in
                            HStack(spacing: 10) {
                                MagpieIconView(icon: agent.icon ?? agent.id, name: agent.name, size: 22, cornerRadius: 5)
                                Text(agent.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                if agent.isPartial {
                                    MagpieStatusChip(text: String(localized: "不完整"), color: MagpieTheme.amber)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { agent.isOn || agent.isPartial },
                                    set: { on in
                                        guard let client = app.client else { return }
                                        Task { await viewModel.setBili(client: client, agent: agent.id, on: on) }
                                    }
                                ))
                                .labelsHidden()
                                .tint(MagpieTheme.green)
                                .disabled(bili.path == nil)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .overlay(
                                Divider().background(MagpieTheme.borderSubtle),
                                alignment: .bottom
                            )
                        }
                    } else {
                        Text(String(localized: "没有 Agent 可以使用 billion-context。"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                            .padding(14)
                    }
                }
                .magpieCard(padding: 0)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.red)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .task {
            if viewModel.bili == nil, let client = app.client {
                await viewModel.loadBili(client: client)
            }
        }
        .refreshable {
            if let client = app.client {
                await viewModel.loadBili(client: client)
            }
        }
    }

    private func savedSummary(_ saved: BiliSavedDTO) -> some View {
        let hasFolds = saved.hasFolds ?? false
        let net = saved.net ?? 0
        let folds = saved.folds ?? 0
        let sessions = saved.sessions ?? 0
        let requests = saved.requests ?? 0
        let tokensText = UsageDTO.formatTokens(Int(abs(net)))
        let summary: String
        if hasFolds {
            summary = String(localized: "已保存 \(tokensText) Token，覆盖 \(folds) 次折叠 · \(sessions) 个会话")
        } else {
            summary = String(localized: "\(requests) 个请求还没有折叠：会话接近模型窗口时才折叠。")
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(summary)
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if hasFolds {
                Text(String(localized: "billion-context 自己的统计，含折叠后的重建与摘要成本。"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
            if saved.live == false, let at = saved.at {
                Text(String(localized: "截至 \(at)：billion-context 当前未运行。"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - RTK（`/api/library/rtk`）
struct LibraryRTKSection: View {
    @Environment(AppModel.self) private var app
    @Environment(PiRTKViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "RTK 是 agents 的模型路由：哪些 Agent 接入了它，以及版本与 PATH。"))
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)

            if let rtk = viewModel.rtk {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        MagpieIconView(icon: "rtk", name: "RTK", size: 30, cornerRadius: 7)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RTK")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            HStack(spacing: 5) {
                                if let version = rtk.version {
                                    MagpieStatusChip(text: "v\(version)", color: MagpieTheme.accent)
                                }
                                if let latest = rtk.latest, latest != rtk.version {
                                    MagpieStatusChip(text: String(localized: "v\(latest) 可升级"), color: MagpieTheme.amber)
                                }
                            }
                        }
                        Spacer()

                        if let upgrade = rtk.upgrade, !upgrade.isEmpty {
                            Button(String(localized: "升级")) {
                                guard let client = app.client else { return }
                                Task { await viewModel.upgradeRTK(client: client) }
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(MagpieTheme.accent)
                        }

                        if rtk.offPath == true {
                            Button(String(localized: "加入 PATH")) {
                                guard let client = app.client else { return }
                                Task { await viewModel.pathRTK(client: client) }
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(MagpieTheme.amber)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if let gain = rtk.gain {
                        Divider().background(MagpieTheme.borderSubtle)
                        HStack(spacing: 0) {
                            gainMetric(String(localized: "调用"), "\(gain.calls ?? 0)")
                            gainDivider
                            gainMetric(String(localized: "Tokens"), UsageDTO.formatTokens(gain.tokens ?? 0))
                            gainDivider
                            gainMetric(String(localized: "费用"), gain.cost.map { String(format: "$%.2f", $0) } ?? "—")
                        }
                        .padding(.vertical, 10)
                    }

                    Divider().background(MagpieTheme.borderSubtle)

                    if let agents = rtk.agents, !agents.isEmpty {
                        ForEach(agents) { agent in
                            HStack(spacing: 10) {
                                MagpieIconView(icon: agent.agent, name: agent.agent, size: 22, cornerRadius: 5)
                                Text(agent.agent)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { agent.on ?? false },
                                    set: { on in
                                        guard let client = app.client else { return }
                                        Task { await viewModel.setRTK(client: client, agent: agent.agent, on: on) }
                                    }
                                ))
                                .labelsHidden()
                                .tint(MagpieTheme.green)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .overlay(
                                Divider().background(MagpieTheme.borderSubtle),
                                alignment: .bottom
                            )
                        }
                    } else {
                        Text(String(localized: "没有 Agent 接入 RTK。"))
                            .font(.caption2)
                            .foregroundStyle(MagpieTheme.textMuted)
                            .padding(14)
                    }
                }
                .magpieCard(padding: 0)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.red)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .task {
            if viewModel.rtk == nil, let client = app.client {
                await viewModel.loadRTK(client: client)
            }
        }
        .refreshable {
            if let client = app.client {
                await viewModel.loadRTK(client: client)
            }
        }
    }

    private func gainMetric(_ title: String, _ value: String) -> some View {
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

    private var gainDivider: some View {
        Rectangle()
            .fill(MagpieTheme.borderSubtle)
            .frame(width: 1, height: 22)
    }
}
