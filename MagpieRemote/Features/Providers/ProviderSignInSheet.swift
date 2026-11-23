import SwiftUI
import UIKit

/// 订阅账号登录（官方 `/api/signin` 流程）：
/// 触发 magpie 的浏览器登录，等待服务器回调完成，或直接粘贴 Claude setup-token。
struct ProviderSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @Environment(ProvidersViewModel.self) private var viewModel

    @State private var agent = "claude"
    @State private var site = ""
    @State private var phase: Phase = .idle
    @State private var signInID = ""
    @State private var statusDetail = ""
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var callbackURL = ""
    @State private var token = ""
    @State private var tokenWorking = false
    @State private var signInURL: String?

    enum Phase: Equatable {
        case idle, starting, waiting, done, failed
    }

    private struct SignInAgent: Identifiable {
        let id: String
        let name: String
        let icon: String
    }

    private let agents: [SignInAgent] = [
        SignInAgent(id: "claude", name: "Claude Code", icon: "claudecode-color"),
        SignInAgent(id: "codex", name: "ChatGPT / Codex", icon: "codex-color"),
        SignInAgent(id: "copilot", name: "GitHub Copilot", icon: "githubcopilot")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    agentCard
                    if agent == "claude" {
                        tokenCard
                    }
                    statusCard
                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                            Spacer(minLength: 0)
                        }
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .magpieCard(padding: 12)
                    }
                }
                .padding(16)
            }
            .magpiePageBackground()
            .navigationTitle(String(localized: "订阅账号登录"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "关闭")) {
                        cancelSignIn()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                pollTask?.cancel()
            }
        }
    }

    // MARK: - 说明
    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MagpieTheme.accent)
                Text(String(localized: "把订阅账号接入 magpie"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
            }
            Text(String(localized: "magpie 会在服务器所在的电脑上打开厂商的登录页。登录完成后，账号会作为一个 Provider 出现在列表里，其它 Agent 也能共用它的模型。"))
                .font(.caption)
                .foregroundStyle(MagpieTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .magpieCard()
    }

    // MARK: - 选择 Agent
    private var agentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "选择要登录的订阅"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MagpieTheme.textMuted)

            VStack(spacing: 0) {
                ForEach(Array(agents.enumerated()), id: \.element.id) { index, item in
                    Button {
                        agent = item.id
                        phase = .idle
                        statusDetail = ""
                        errorMessage = nil
                    } label: {
                        HStack(spacing: 11) {
                            MagpieIconView(icon: item.icon, name: item.name, size: 28, cornerRadius: 6)
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            Spacer()
                            Image(systemName: agent == item.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(agent == item.id ? MagpieTheme.accent : MagpieTheme.textMuted)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < agents.count - 1 {
                        Divider().background(MagpieTheme.borderSubtle).padding(.leading, 52)
                    }
                }
            }
            .magpieCard(padding: 0)

            HStack(spacing: 8) {
                TextField(String(localized: "站点（可选，如 zai / bigmodel）"), text: $site)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(9)
                    .background(MagpieTheme.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                startSignIn()
            } label: {
                HStack {
                    Spacer()
                    if phase == .starting || phase == .waiting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(String(localized: "开始登录"))
                            .font(.subheadline.weight(.bold))
                    }
                    Spacer()
                }
                .padding(.vertical, 13)
            }
            .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.accent))
            .disabled(phase == .starting || phase == .waiting)
        }
        .magpieCard()
    }

    // MARK: - Claude setup-token
    private var tokenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "或粘贴 Claude setup-token"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MagpieTheme.textPrimary)
            Text(String(localized: "在电脑上运行 claude setup-token，把输出的 token 粘贴到下面。它不会显示在页面上。"))
                .font(.caption2)
                .foregroundStyle(MagpieTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                SecureField("sk-ant-oat01-…", text: $token)
                    .font(.system(size: 11, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(9)
                    .background(MagpieTheme.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    addClaudeToken()
                } label: {
                    if tokenWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(String(localized: "添加"))
                    }
                }
                .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.amber))
                .disabled(tokenWorking || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .magpieCard()
    }

    // MARK: - 状态
    @ViewBuilder
    private var statusCard: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .starting:
            stateCard(icon: "hourglass", tint: MagpieTheme.accent, title: String(localized: "正在向 magpie 发起登录…"))
        case .waiting:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "等待浏览器完成登录"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Spacer()
                }
                if !statusDetail.isEmpty {
                    Text(statusDetail)
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textMuted)
                }
                Text(String(localized: "登录页已在 magpie 所在电脑的浏览器打开；完成后这里会自动继续。若浏览器没有打开，可点下方按钮重试。"))
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        reopenSignInURL()
                    } label: {
                        Label(String(localized: "再次打开登录页"), systemImage: "safari")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MagpieTheme.accent)

                    Spacer()

                    Button {
                        cancelSignIn()
                        phase = .idle
                    } label: {
                        Text(String(localized: "取消登录"))
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MagpieTheme.red)
                }

                Divider().background(MagpieTheme.borderSubtle)

                Text(String(localized: "若浏览器停在回调地址，可把它粘贴到这里完成登录："))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
                HStack(spacing: 8) {
                    TextField("https://…", text: $callbackURL)
                        .font(.system(size: 10.5, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(8)
                        .background(MagpieTheme.cardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Button(String(localized: "提交")) {
                        submitCallback()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(MagpieTheme.accent)
                    .disabled(callbackURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .magpieCard()
        case .done:
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(MagpieTheme.green)
                Text(String(localized: "登录完成"))
                    .font(.headline)
                    .foregroundStyle(MagpieTheme.textPrimary)
                if !statusDetail.isEmpty {
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textSecondary)
                }
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "完成"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.green))
            }
            .frame(maxWidth: .infinity)
            .magpieCard()
        case .failed:
            stateCard(
                icon: "xmark.circle.fill",
                tint: MagpieTheme.red,
                title: String(localized: "登录没有完成"),
                detail: String(localized: "可以重试，或改用其他登录方式。")
            )
        }
    }

    private func stateCard(icon: String, tint: Color, title: String, detail: String? = nil) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MagpieTheme.textPrimary)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .magpieCard()
    }

    // MARK: - 逻辑
    private func startSignIn() {
        guard let client = app.client else { return }
        phase = .starting
        errorMessage = nil
        statusDetail = ""

        Task {
            do {
                var body: [String: Any] = ["Agent": agent]
                let trimmedSite = site.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSite.isEmpty { body["Site"] = trimmedSite }
                let data = try JSONSerialization.data(withJSONObject: body)
                let responseData = try await client.sendData(
                    Endpoint(path: "/api/signin", method: .post, body: data)
                )
                let status = try? JSONDecoder().decode(JSONValue.self, from: responseData)
                let id = status?.string("id")
                    ?? status?.objectValue?["signIn"]?.string("id")
                    ?? status?.objectValue?["status"]?.string("id")
                    ?? ""
                signInID = id

                let url = signInURL(from: status)
                self.signInURL = url
                if let url, let target = URL(string: url) {
                    _ = await UIApplication.shared.open(target)
                }

                if id.isEmpty {
                    phase = .failed
                    errorMessage = String(localized: "magpie 没有返回登录会话，请确认服务端版本支持网页登录。")
                } else {
                    phase = .waiting
                    statusDetail = status?.string("status") ?? ""
                    pollSignIn(id: id, client: client)
                }
            } catch {
                phase = .failed
                errorMessage = APIError.message(for: error)
            }
        }
    }

    private func signInURL(from status: JSONValue?) -> String? {
        status?.string("url")
            ?? status?.string("authURL")
            ?? status?.string("authUrl")
            ?? status?.string("link")
            ?? status?.objectValue?["signIn"]?.string("url")
            ?? status?.objectValue?["status"]?.string("url")
    }

    private func reopenSignInURL() {
        if let url = signInURL, let target = URL(string: url) {
            Task { _ = await UIApplication.shared.open(target) }
        } else {
            startSignIn()
        }
    }

    private func pollSignIn(id: String, client: MagpieAPIClient) {
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<90 {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                do {
                    let data = try await client.sendData(.get("/api/signin/\(id)"))
                    let status = try? JSONDecoder().decode(JSONValue.self, from: data)
                    let text = (status?.string("status") ?? status?.string("state") ?? "").lowercased()
                    let failure = status?.string("error") ?? ""
                    if !failure.isEmpty {
                        phase = .failed
                        errorMessage = failure
                        return
                    }
                    if ["failed", "error", "canceled", "cancelled", "expired"].contains(text) {
                        phase = .failed
                        errorMessage = status?.string("message") ?? text
                        return
                    }
                    let done = status?.bool("done") == true
                        || status?.bool("finished") == true
                        || status?.bool("signedIn") == true
                        || ["done", "success", "ok", "signed-in", "signedin", "signed_in", "complete", "completed"].contains(text)
                    if done {
                        statusDetail = status?.string("user") ?? status?.string("name") ?? ""
                        await reloadProviders(client: client)
                        phase = .done
                        return
                    }
                    if !text.isEmpty { statusDetail = text }
                } catch {
                    // 网络抖动继续等待。
                }
            }
            phase = .failed
            errorMessage = String(localized: "登录超时：请在电脑浏览器完成登录后重试。")
        }
    }

    private func reloadProviders(client: MagpieAPIClient) async {
        await viewModel.load(client: client)
        await app.refresh()
        MagpieHaptics.success()
    }

    private func submitCallback() {
        let url = callbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !signInID.isEmpty, let client = app.client else { return }
        let id = signInID
        Task {
            do {
                let body: [String: Any] = ["url": url]
                let data = try JSONSerialization.data(withJSONObject: body)
                _ = try await client.sendData(
                    Endpoint(path: "/api/signin/\(id)/callback", method: .post, body: data)
                )
                callbackURL = ""
                await reloadProviders(client: client)
                phase = .done
            } catch {
                errorMessage = APIError.message(for: error)
            }
        }
    }

    private func addClaudeToken() {
        guard let client = app.client else { return }
        tokenWorking = true
        errorMessage = nil
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            defer { tokenWorking = false }
            do {
                struct Body: Encodable { let Token: String }
                _ = try await client.sendData(
                    try Endpoint.post("/api/signin/claude-token", body: Body(Token: value))
                )
                token = ""
                statusDetail = String(localized: "setup-token 已保存")
                await reloadProviders(client: client)
                phase = .done
            } catch {
                phase = .failed
                errorMessage = APIError.message(for: error)
            }
        }
    }

    private func cancelSignIn() {
        pollTask?.cancel()
        pollTask = nil
        guard !signInID.isEmpty, let client = app.client else { return }
        let id = signInID
        signInID = ""
        Task {
            _ = try? await client.sendData(.post("/api/signin/\(id)/cancel"))
        }
    }
}
