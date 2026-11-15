import SwiftUI
import UIKit

/// 插件 Provider 的登录：按 OpenCode 的 auth 流程逐步提问，
/// 之后进入浏览器（OAuth）或直接保存 API Key。
struct PluginSignInSheet: View {
    let plugin: PluginSubDTO

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @Environment(ProvidersViewModel.self) private var viewModel

    @State private var phase: Phase = .idle
    @State private var methodIndex: Int?
    @State private var inputs: [String: String] = [:]
    @State private var prompt: PluginPromptDTO?
    @State private var answer = ""
    @State private var apiKey = ""
    @State private var state: PluginSignInStateDTO?
    @State private var callbackURL = ""
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?

    enum Phase: Equatable {
        case idle, method, prompt, key, waiting, done, failed
    }

    private var methods: [PluginMethodDTO] { plugin.methods ?? [] }

    private var currentMethod: PluginMethodDTO? {
        guard let methodIndex, methods.indices.contains(methodIndex) else { return nil }
        return methods[methodIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
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
            .navigationTitle(String(localized: "登录 \(plugin.displayName)"))
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

    // MARK: - 头部
    private var headerCard: some View {
        HStack(spacing: 12) {
            MagpieIconView(icon: plugin.icon ?? plugin.id, name: plugin.displayName, size: 40, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plugin.displayName)
                        .font(.headline)
                        .foregroundStyle(MagpieTheme.textPrimary)
                    if plugin.isSignedIn {
                        MagpieStatusChip(text: String(localized: "已登录"), color: MagpieTheme.green)
                    }
                }
                Text(plugin.spec)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
                if let models = plugin.models, models > 0 {
                    Text(String(localized: "\(models) 个模型"))
                        .font(.caption2)
                        .foregroundStyle(MagpieTheme.textSecondary)
                }
            }
            Spacer()
        }
        .magpieCard()
    }

    // MARK: - 状态
    @ViewBuilder
    private var statusCard: some View {
        switch phase {
        case .idle:
            VStack(spacing: 10) {
                Text(String(localized: "这个 Provider 由插件「\(plugin.spec)」提供，登录后它的模型会出现在 Providers 列表。"))
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    if methods.count > 1 {
                        phase = .method
                    } else if !methods.isEmpty {
                        start(method: 0)
                    } else {
                        phase = .failed
                        errorMessage = String(localized: "这个插件没有可用的登录方式。")
                    }
                } label: {
                    Text(String(localized: "开始登录"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.accent))
            }
            .frame(maxWidth: .infinity)
            .magpieCard()

        case .method:
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "选择登录方式"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                ForEach(methods.indices, id: \.self) { index in
                    let method = methods[index]
                    Button {
                        start(method: index)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: method.isAPI ? "key.fill" : "safari.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MagpieTheme.accent)
                            Text(method.displayLabel)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MagpieTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MagpieTheme.textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(MagpieTheme.cardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .magpieCard()

        case .prompt:
            if let prompt {
                VStack(alignment: .leading, spacing: 10) {
                    Text(prompt.displayMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MagpieTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if prompt.isSelect {
                        ForEach(prompt.options ?? []) { option in
                            Button {
                                answerPrompt(option.value ?? option.displayLabel)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.displayLabel)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(MagpieTheme.textPrimary)
                                    if let hint = option.displayHint {
                                        Text(hint)
                                            .font(.caption2)
                                            .foregroundStyle(MagpieTheme.textMuted)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(MagpieTheme.cardSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 8) {
                            if prompt.type == "password" {
                                SecureField(prompt.placeholder ?? "", text: $answer)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                TextField(prompt.placeholder ?? "", text: $answer)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            Button(String(localized: "下一步")) {
                                answerPrompt(answer)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(MagpieTheme.accent)
                            .disabled(answer.isEmpty)
                        }
                        .padding(10)
                        .background(MagpieTheme.cardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .magpieCard()
            }

        case .key:
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "\(plugin.displayName) API Key"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                SecureField(currentMethod?.placeholder ?? "", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(10)
                    .background(MagpieTheme.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                if let keysURL = currentMethodKeysURL, let url = URL(string: keysURL) {
                    Link(destination: url) {
                        Text(String(localized: "获取 API Key"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(MagpieTheme.accent)
                    }
                }
                Button {
                    submitKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Text(String(localized: "登录"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(MagpiePrimaryButtonStyle(tint: MagpieTheme.accent))
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .magpieCard()

        case .waiting:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "等待浏览器完成登录"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MagpieTheme.textPrimary)
                    Spacer()
                }

                if let code = state?.code, !code.isEmpty {
                    Text(String(localized: "验证码：\(code)"))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MagpieTheme.accent)
                        .textSelection(.enabled)
                }

                if let instructions = state?.instructions, !instructions.isEmpty {
                    Text(instructions)
                        .font(.caption)
                        .foregroundStyle(MagpieTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button {
                        openSignInPage()
                    } label: {
                        Label(String(localized: "打开登录页"), systemImage: "safari")
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

                if state?.pasteCallback == true {
                    Divider().background(MagpieTheme.borderSubtle)
                    Text(String(localized: "把浏览器最终停留的回调地址粘贴到这里："))
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
                if let user = state?.user, !user.isEmpty {
                    Text(user)
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
            VStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(MagpieTheme.red)
                Text(String(localized: "登录没有完成"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Button(String(localized: "重试")) {
                    phase = .idle
                    errorMessage = nil
                    inputs = [:]
                    prompt = nil
                    state = nil
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(MagpieTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .magpieCard()
        }
    }

    private var currentMethodKeysURL: String? {
        state?.keysURL
    }

    // MARK: - 流程
    private func start(method index: Int) {
        methodIndex = index
        inputs = [:]
        prompt = nil
        errorMessage = nil
        callPrompt()
    }

    private func callPrompt() {
        guard let client = app.client, let methodIndex else { return }
        let pid = plugin.pid ?? plugin.id
        Task {
            let response = await viewModel.pluginPrompt(
                client: client,
                provider: pid,
                method: methodIndex,
                inputs: inputs
            )
            guard let response else {
                phase = .failed
                errorMessage = viewModel.errorMessage
                return
            }
            if let error = response.error, !error.isEmpty {
                errorMessage = error
                return
            }
            inputs = response.inputs ?? inputs
            if let next = response.prompt {
                prompt = next
                answer = ""
                phase = .prompt
            } else {
                prompt = nil
                afterPrompts()
            }
        }
    }

    private func answerPrompt(_ value: String) {
        guard let client = app.client, let methodIndex, let prompt else { return }
        let pid = plugin.pid ?? plugin.id
        Task {
            let response = await viewModel.pluginPrompt(
                client: client,
                provider: pid,
                method: methodIndex,
                inputs: inputs,
                key: prompt.key,
                value: value
            )
            guard let response else {
                errorMessage = viewModel.errorMessage
                return
            }
            if let error = response.error, !error.isEmpty {
                errorMessage = error
                return
            }
            inputs = response.inputs ?? inputs
            if let next = response.prompt {
                self.prompt = next
                answer = ""
            } else {
                self.prompt = nil
                afterPrompts()
            }
        }
    }

    private func afterPrompts() {
        guard let method = currentMethod else {
            phase = .failed
            errorMessage = String(localized: "登录方式丢失，请重试。")
            return
        }
        if method.isAPI {
            if method.keyless == true || method.keyAsked == true {
                submitKey("")
            } else {
                phase = .key
            }
        } else {
            startOAuth()
        }
    }

    private func submitKey(_ key: String) {
        guard let client = app.client, let methodIndex else { return }
        let pid = plugin.pid ?? plugin.id
        Task {
            let state = await viewModel.pluginSignIn(
                client: client,
                provider: pid,
                method: methodIndex,
                inputs: inputs,
                key: key
            )
            handle(state)
        }
    }

    private func startOAuth() {
        guard let client = app.client, let methodIndex else { return }
        let pid = plugin.pid ?? plugin.id
        phase = .waiting
        Task {
            let state = await viewModel.pluginSignIn(
                client: client,
                provider: pid,
                method: methodIndex,
                inputs: inputs
            )
            handle(state)
        }
    }

    private func handle(_ st: PluginSignInStateDTO?) {
        guard let st else {
            phase = .failed
            errorMessage = viewModel.errorMessage
            return
        }
        state = st
        if let error = st.error, !error.isEmpty {
            phase = .failed
            errorMessage = error
            return
        }
        if st.state == "done" {
            finishSuccess()
            return
        }
        if st.canceled == true {
            phase = .failed
            errorMessage = String(localized: "登录已取消。")
            return
        }
        phase = .waiting
        if let url = st.url, let target = URL(string: url) {
            Task { _ = await UIApplication.shared.open(target) }
        }
        if let id = st.id, !id.isEmpty {
            pollSignIn(id: id)
        }
    }

    private func pollSignIn(id: String) {
        guard let client = app.client else { return }
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<90 {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { return }
                do {
                    let data = try await client.sendData(.get("/api/signin/\(id)"))
                    let value = try? JSONDecoder().decode(JSONValue.self, from: data)
                    let stateText = (value?.string("state") ?? value?.string("status") ?? "").lowercased()
                    if let error = value?.string("error"), !error.isEmpty {
                        phase = .failed
                        errorMessage = error
                        return
                    }
                    if let user = value?.string("user"), !user.isEmpty {
                        state?.user = user
                    }
                    if let url = value?.string("url"), !url.isEmpty {
                        state?.url = url
                    }
                    if ["done", "success", "ok"].contains(stateText) || value?.bool("done") == true {
                        finishSuccess()
                        return
                    }
                    if ["failed", "error", "canceled", "cancelled"].contains(stateText) {
                        phase = .failed
                        errorMessage = value?.string("error") ?? String(localized: "登录失败。")
                        return
                    }
                } catch {
                    // 网络抖动继续等待
                }
            }
            phase = .failed
            errorMessage = String(localized: "登录超时，请重试。")
        }
    }

    private func submitCallback() {
        guard let client = app.client, let id = state?.id, !id.isEmpty else { return }
        let url = callbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        Task {
            do {
                let body: [String: Any] = ["url": url]
                let data = try JSONSerialization.data(withJSONObject: body)
                _ = try await client.sendData(
                    Endpoint(path: "/api/signin/\(id)/callback", method: .post, body: data)
                )
                callbackURL = ""
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func openSignInPage() {
        guard let url = state?.url, let target = URL(string: url) else { return }
        Task { _ = await UIApplication.shared.open(target) }
    }

    private func finishSuccess() {
        guard let client = app.client else { return }
        Task {
            await viewModel.load(client: client)
            await app.refresh()
            phase = .done
            MagpieHaptics.success()
        }
    }

    private func cancelSignIn() {
        pollTask?.cancel()
        pollTask = nil
        guard let client = app.client, let id = state?.id, !id.isEmpty else { return }
        Task {
            _ = try? await client.sendData(.post("/api/signin/\(id)/cancel"))
        }
    }
}
