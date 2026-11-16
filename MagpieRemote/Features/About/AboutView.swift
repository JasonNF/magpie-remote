import SwiftUI

// MARK: - 数据模型
private struct AboutLink: Identifiable {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let url: String
    let tint: Color

    var id: String { "\(title)|\(url)" }
}

private struct AboutCapability: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let highlights: [String]
    let actions: [AboutLink]
    let icon: String
    let tint: Color
}

// MARK: - 关于
struct AboutView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showPrivacyPolicy = false
    @State private var appeared = false
    @State private var isAnimatingLogo = false
    @State private var logoRotation: Double = 0

    private static let repository = "https://github.com/zxfccmm4/magpie-remote"
    private static let issues = "https://github.com/zxfccmm4/magpie-remote/issues"
    private static let magpieRepository = "https://github.com/yetone/magpie"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var introDelay: Double {
        reduceMotion ? 0 : 0.08
    }

    private var connectLinks: [AboutLink] {
        [
            AboutLink(
                title: "GitHub",
                subtitle: "查看 Magpie Remote 源码与更新",
                icon: "chevron.left.forwardslash.chevron.right",
                url: Self.repository,
                tint: MagpieTheme.accent
            ),
            AboutLink(
                title: "反馈问题",
                subtitle: "在 Magpie Remote Issues 报告问题或提出建议",
                icon: "exclamationmark.bubble.fill",
                url: Self.issues,
                tint: MagpieTheme.amber
            ),
            AboutLink(
                title: "开发者 X",
                subtitle: "关注 Magpie Remote 的最新动态",
                icon: "at",
                url: "https://twitter.com/st7evechou",
                tint: MagpieTheme.cyan
            ),
            AboutLink(
                title: "Telegram",
                subtitle: "加入交流群，和其他用户一起讨论",
                icon: "paperplane.fill",
                url: "https://t.me/st7evee",
                tint: MagpieTheme.green
            ),
            AboutLink(
                title: "邮件反馈",
                subtitle: "把使用体验和建议直接发给我",
                icon: "envelope.fill",
                url: "mailto:zxfccmm@gmail.com?subject=Feedback%20for%20Magpie%20Remote",
                tint: MagpieTheme.purple
            ),
        ]
    }

    private var thanksLinks: [AboutLink] {
        [
            AboutLink(
                title: "magpie",
                subtitle: "本地 AI 网关，App 的全部管理能力来自它",
                icon: "bird.fill",
                url: Self.magpieRepository,
                tint: MagpieTheme.accent
            ),
            AboutLink(
                title: "SwiftUI",
                subtitle: "声明式界面、动画与 Liquid Glass",
                icon: "swift",
                url: "https://developer.apple.com/xcode/swiftui/",
                tint: MagpieTheme.amber
            ),
            AboutLink(
                title: "SwiftData",
                subtitle: "本机连接与状态持久化",
                icon: "externaldrive.fill",
                url: "https://developer.apple.com/xcode/swiftdata/",
                tint: MagpieTheme.cyan
            ),
            AboutLink(
                title: "Keychain Services",
                subtitle: "Web Key 与凭据的安全存储",
                icon: "key.fill",
                url: "https://developer.apple.com/documentation/security/keychain_services",
                tint: MagpieTheme.purple
            ),
        ]
    }

    private var capabilities: [AboutCapability] {
        [
            AboutCapability(
                id: "providers",
                title: "模型提供商",
                subtitle: "Provider、Key 与模型目录",
                detail: "集中管理 magpie 的所有模型来源：多 Key、多账号轮换、端点与协议、模型可用性，以及每个模型的上下文和推理档。",
                highlights: [
                    "管理 Chat、Responses、Anthropic 与 Gemini 端点",
                    "多密钥与订阅账号自动轮换",
                    "按模型设置上下文、输出上限与图片能力",
                ],
                actions: [
                    AboutLink(title: "查看 Magpie Remote 源码", icon: "chevron.left.forwardslash.chevron.right", url: Self.repository, tint: MagpieTheme.amber),
                    AboutLink(title: "反馈问题", icon: "exclamationmark.bubble.fill", url: Self.issues, tint: MagpieTheme.amber),
                ],
                icon: "key.radiowaves.forward",
                tint: MagpieTheme.amber
            ),
            AboutCapability(
                id: "agents",
                title: "智能体",
                subtitle: "Claude Code、Codex、Gemini CLI",
                detail: "查看并修改每个 Agent 正在使用的模型与配置，不必登录远端机器，也不用记口令。",
                highlights: [
                    "一键为本地 Agent 切换模型",
                    "读取并展示 Agent 配置文件",
                    "连接状态、版本与配置诊断",
                ],
                actions: [
                    AboutLink(title: "查看 Magpie Remote 源码", icon: "chevron.left.forwardslash.chevron.right", url: Self.repository, tint: MagpieTheme.accent),
                    AboutLink(title: "反馈问题", icon: "exclamationmark.bubble.fill", url: Self.issues, tint: MagpieTheme.accent),
                ],
                icon: "terminal",
                tint: MagpieTheme.accent
            ),
            AboutCapability(
                id: "routing",
                title: "路由与负载均衡",
                subtitle: "智能选择、故障转移",
                detail: "通过路由组与策略把请求分配到不同 Provider，支持权重、限流、优先级与故障转移。",
                highlights: [
                    "路由组与策略模板",
                    "实时决策链与候选来源",
                    "按账号配额自动切换",
                ],
                actions: [
                    AboutLink(title: "查看 Magpie Remote 源码", icon: "chevron.left.forwardslash.chevron.right", url: Self.repository, tint: MagpieTheme.purple),
                    AboutLink(title: "反馈问题", icon: "exclamationmark.bubble.fill", url: Self.issues, tint: MagpieTheme.purple),
                ],
                icon: "arrow.triangle.branch",
                tint: MagpieTheme.purple
            ),
            AboutCapability(
                id: "usage",
                title: "用量与配额",
                subtitle: "Token、成本与账户余量",
                detail: "按 Agent、模型、账号与网关 Key 汇总调用量、Token、缓存和成本，并查看各账号的剩余配额。",
                highlights: [
                    "实时请求与 Token 统计",
                    "账户配额、余额与重置时间",
                    "按时间范围查看趋势与热力图",
                ],
                actions: [
                    AboutLink(title: "查看 Magpie Remote 源码", icon: "chevron.left.forwardslash.chevron.right", url: Self.repository, tint: MagpieTheme.green),
                    AboutLink(title: "反馈问题", icon: "exclamationmark.bubble.fill", url: Self.issues, tint: MagpieTheme.green),
                ],
                icon: "chart.bar.xaxis",
                tint: MagpieTheme.green
            ),
            AboutCapability(
                id: "sessions",
                title: "会话",
                subtitle: "历史记录与转录",
                detail: "浏览 magpie 记录的历史会话，查看每次会话使用的模型、Token 与成本，并导出完整转录。",
                highlights: [
                    "按 Agent 与会话检索",
                    "查看完整 transcript",
                    "统计每次会话的成本",
                ],
                actions: [
                    AboutLink(title: "查看 Magpie Remote 源码", icon: "chevron.left.forwardslash.chevron.right", url: Self.repository, tint: MagpieTheme.cyan),
                    AboutLink(title: "反馈问题", icon: "exclamationmark.bubble.fill", url: Self.issues, tint: MagpieTheme.cyan),
                ],
                icon: "bubble.left.and.bubble.right",
                tint: MagpieTheme.cyan
            ),
            AboutCapability(
                id: "masking",
                title: "隐私脱敏",
                subtitle: "发送前过滤敏感信息",
                detail: "在请求发往 Provider 前替换密钥、邮箱、电话等敏感内容，并在截图时隐藏账号名。",
                highlights: [
                    "可自定义脱敏规则",
                    "按 Provider 控制是否跳过脱敏",
                    "路由与用量页面一键隐藏账号",
                ],
                actions: [
                    AboutLink(title: "查看 Magpie Remote 源码", icon: "chevron.left.forwardslash.chevron.right", url: Self.repository, tint: MagpieTheme.pink),
                    AboutLink(title: "反馈问题", icon: "exclamationmark.bubble.fill", url: Self.issues, tint: MagpieTheme.pink),
                ],
                icon: "shield.lefthalf.filled",
                tint: MagpieTheme.pink
            ),
        ]
    }

    var body: some View {
        MagpieNavigationContainer {
            ScrollView {
                VStack(spacing: 20) {
                    AboutHeader(
                        version: appVersion,
                        build: buildNumber,
                        isAnimating: isAnimatingLogo && !reduceMotion,
                        rotation: logoRotation
                    )
                    .aboutReveal(appeared: appeared, delay: introDelay, reduceMotion: reduceMotion)

                    AboutCapabilityCarousel(capabilities: capabilities)
                        .aboutReveal(appeared: appeared, delay: introDelay * 2, reduceMotion: reduceMotion)

                    AboutLinkSection(title: "连接与反馈", links: connectLinks)
                        .aboutReveal(appeared: appeared, delay: introDelay * 3, reduceMotion: reduceMotion)

                    AboutLinkSection(title: "特别感谢", links: thanksLinks)
                        .aboutReveal(appeared: appeared, delay: introDelay * 4, reduceMotion: reduceMotion)

                    AboutLegalSection {
                        showPrivacyPolicy = true
                    }
                    .aboutReveal(appeared: appeared, delay: introDelay * 5, reduceMotion: reduceMotion)

                    AboutCreditsCard {
                        MagpieHaptics.light()
                        guard !reduceMotion else { return }
                        withAnimation(.spring(duration: 0.45, bounce: 0.42)) {
                            logoRotation += 12
                        }
                    }
                    .aboutReveal(appeared: appeared, delay: introDelay * 6, reduceMotion: reduceMotion)

                    Text("Magpie Remote · 原生 SwiftUI")
                        .font(.system(size: 9.5))
                        .foregroundStyle(MagpieTheme.textMuted)
                        .padding(.top, 2)
                        .padding(.bottom, 36)
                }
                .frame(maxWidth: readableContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 18)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "关于"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
                .presentationDetents([.medium, .large])
        }
        .task {
            appeared = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isAnimatingLogo = true
            }
        }
    }

    private var readableContentWidth: CGFloat {
        horizontalSizeClass == .regular ? 820 : .infinity
    }

    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
}

// MARK: - 头部
private struct AboutHeader: View {
    let version: String
    let build: String
    let isAnimating: Bool
    let rotation: Double

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MagpieTheme.card)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)

                MagpieLogoView(size: 72, showText: false, isAnimated: false)
                    .padding(10)
            }
            .frame(width: 104, height: 104)
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
            .rotation3DEffect(.degrees(isAnimating ? 3 : -3), axis: (x: 1, y: 1, z: 0))
            .scaleEffect(isAnimating ? 1.02 : 0.98)
            .rotationEffect(.degrees(rotation))
            .padding(.top, 22)

            Text("Magpie Remote")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(MagpieTheme.textPrimary)

            Text("远程管理你的 magpie AI 网关")
                .font(.subheadline)
                .foregroundStyle(MagpieTheme.textSecondary)

            Text("版本 \(version) (\(build))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MagpieTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }
}

// MARK: - 能力横向卡片
private struct AboutCapabilityCarousel: View {
    let capabilities: [AboutCapability]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AboutSectionTitle(title: "核心能力")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(capabilities) { item in
                        NavigationLink {
                            AboutCapabilityDetailView(item: item)
                        } label: {
                            AboutCapabilityCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.9)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 4)
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct AboutCapabilityCard: View {
    let item: AboutCapability

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.tint.opacity(0.14))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(item.tint)
                    }

                Text(item.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }

            Text(item.subtitle)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(MagpieTheme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Capsule(style: .continuous)
                .fill(item.tint.opacity(0.55))
                .frame(width: 22, height: 4)
        }
        .padding(11)
        .frame(width: 150, height: 112)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MagpieTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)
        )
    }
}

// MARK: - 能力详情
private struct AboutCapabilityDetailView: View {
    let item: AboutCapability
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(item.tint)
                        .frame(width: 50, height: 50)
                        .background(item.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(item.tint.opacity(0.25), lineWidth: 1)
                        }

                    Text(item.title)
                        .font(.title3.bold())
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(MagpieTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(MagpieTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("概览")
                        .font(.headline)
                    Text(item.detail)
                        .font(.body)
                        .foregroundStyle(MagpieTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("要点")
                        .font(.headline)
                    ForEach(Array(item.highlights.enumerated()), id: \.offset) { _, highlight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(item.tint)
                                .font(.caption)
                                .padding(.top, 3)
                            Text(highlight)
                                .font(.subheadline)
                                .foregroundStyle(MagpieTheme.textSecondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("相关链接")
                        .font(.headline)
                    ForEach(item.actions) { action in
                        Button {
                            guard let url = URL(string: action.url) else { return }
                            openURL(url)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: action.icon)
                                    .foregroundStyle(item.tint)
                                    .frame(width: 20)
                                Text(action.title)
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                                    .foregroundStyle(MagpieTheme.textMuted)
                            }
                            .padding(11)
                            .background(MagpieTheme.cardSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
        }
        .magpiePageBackground()
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 链接列表
private struct AboutLinkSection: View {
    let title: String
    let links: [AboutLink]
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AboutSectionTitle(title: title)

            VStack(spacing: 0) {
                ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                    Button {
                        guard let url = URL(string: link.url) else { return }
                        openURL(url)
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: link.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(link.tint)
                                .frame(width: 30, height: 30)
                                .background(link.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(link.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                if let subtitle = link.subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(MagpieTheme.textSecondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }

                            Spacer(minLength: 6)

                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < links.count - 1 {
                        Divider()
                            .background(MagpieTheme.borderSubtle)
                            .padding(.leading, 57)
                    }
                }
            }
            .background(MagpieTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)
            }
        }
    }
}

// MARK: - 法律与隐私
private struct AboutLegalSection: View {
    let onShowPrivacy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AboutSectionTitle(title: "法律与隐私")

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    MagpieHaptics.light()
                    onShowPrivacy()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MagpieTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(MagpieTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text("隐私政策")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(MagpieTheme.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().background(MagpieTheme.borderSubtle).padding(.leading, 43)

                Text("Magpie Remote 不收集遥测数据；连接地址与 Web Key 只保存在这台设备上。")
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(MagpieTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)
            }
        }
    }
}

// MARK: - 致谢
private struct AboutCreditsCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 13) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(MagpieTheme.red)
                    .frame(width: 30, height: 30)
                    .background(MagpieTheme.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("为 magpie 而作")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Text("用 SwiftUI 原生构建 · 零第三方依赖")
                        .font(.system(size: 12))
                        .foregroundStyle(MagpieTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(MagpieTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MagpieTheme.borderSubtle, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分区标题
private struct AboutSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(MagpieTheme.textPrimary)
            .padding(.horizontal, 4)
    }
}

// MARK: - 入场动画
private extension View {
    func aboutReveal(appeared: Bool, delay: Double, reduceMotion: Bool) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
            .animation(.easeOut(duration: 0.36).delay(delay), value: appeared)
    }
}

// MARK: - 隐私政策
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let paragraphs: [(String, String)] = [
        ("这是一个客户端", "Magpie Remote 只是你自建 magpie 实例的原生客户端。它不会创建账号，也不会上传你的数据到开发者服务器。"),
        ("本机保存的内容", "连接地址、Web Key 与界面偏好保存在这台设备上。Web Key 使用 Keychain Services 存储，连接记录使用 SwiftData 持久化。"),
        ("网络请求", "当你浏览页面、执行测试或修改配置时，App 会直接请求你配置的 magpie 网关。请求内容由你的网关处理，处理方式取决于你自己的部署。"),
        ("不包含追踪", "App 不包含分析、广告或第三方追踪 SDK，也不会在后台收集使用行为。"),
        ("删除数据", "断开或删除连接时，App 会移除对应的本机连接记录与 Keychain 中的 Web Key。"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(paragraph.0)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            Text(paragraph.1)
                                .font(.subheadline)
                                .foregroundStyle(MagpieTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("最后更新：2026 年 11 月")
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textMuted)
                        .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "隐私政策"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
