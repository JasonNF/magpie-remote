import Foundation
import Observation

/// 全局应用状态：当前连接、API 客户端、主数据 state。经 `.environment()` 注入。
@Observable
@MainActor
final class AppModel {
    enum Phase: Sendable {
        case idle, loading, loaded, error
    }

    var activeID: UUID?
    var activeName: String = ""
    var activeURL: URL?
    private(set) var client: MagpieAPIClient?
    var state: StateDTO?
    var phase: Phase = .idle
    var errorMessage: String?
    var isRefreshing = false

    private let lastActiveIDKey = "magpie_last_active_connection_id"

    var lastActiveID: UUID? {
        get {
            guard let str = UserDefaults.standard.string(forKey: lastActiveIDKey) else { return nil }
            return UUID(uuidString: str)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: lastActiveIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastActiveIDKey)
            }
        }
    }

    var isConnected: Bool { activeID != nil && phase == .loaded }

    /// 激活一个连接：从 Keychain 取 Key → 登录 → 拉取 state。
    func activate(id: UUID, name: String, urlString: String) async {
        guard let url = URL(string: urlString), url.scheme != nil else {
            phase = .error
            errorMessage = APIError.invalidURL.errorDescription
            return
        }
        var key = KeychainStore.read(for: id.uuidString)
        if (key == nil || key?.isEmpty == true), urlString.contains("mapm.2020713.xyz") {
            let defaultKey = "79261a46b263781ddc6af6d168a8597543d8065fc5f71f14c2b942bef3f8afa0"
            KeychainStore.save(defaultKey, for: id.uuidString)
            key = defaultKey
        }
        guard let key, !key.isEmpty else {
            phase = .error
            errorMessage = String(localized: "缺少 Web Key，请编辑该连接。")
            return
        }
        activeID = id
        activeName = name
        activeURL = url

        var tlsMaterial: ClientTLSMaterial?
        if let bundle = ClientCertificateStore.load(for: id.uuidString) {
            do {
                tlsMaterial = try ClientCertificateStore.makeTLSMaterial(from: bundle, account: id.uuidString)
            } catch {
                phase = .error
                errorMessage = (error as? ClientCertificateError)?.errorDescription ?? error.localizedDescription
                return
            }
        }

        let client = MagpieAPIClient(baseURL: url, key: key, tlsMaterial: tlsMaterial)
        self.client = client
        phase = .loading
        errorMessage = nil
        do {
            try await client.signIn()
            state = try await client.send(.get("/api/state"), as: StateDTO.self)
            phase = .loaded
            lastActiveID = id
            MagpieHaptics.success()
        } catch {
            phase = .error
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            MagpieHaptics.error()
        }
    }

    /// 重新拉取 state（下拉刷新 / 写操作后）。
    func refresh() async {
        guard let client else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            state = try await client.send(.get("/api/state"), as: StateDTO.self)
            phase = .loaded
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 应用一次写操作返回的最新 state。
    func apply(_ newState: StateDTO) {
        state = newState
        phase = .loaded
    }

    func disconnect() {
        activeID = nil
        activeName = ""
        activeURL = nil
        client = nil
        state = nil
        phase = .idle
        errorMessage = nil
        lastActiveID = nil
    }
}