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

    var isConnected: Bool { activeID != nil && phase == .loaded }

    /// 激活一个连接：从 Keychain 取 Key → 登录 → 拉取 state。
    func activate(id: UUID, name: String, urlString: String) async {
        guard let url = URL(string: urlString), url.scheme != nil else {
            phase = .error
            errorMessage = APIError.invalidURL.errorDescription
            return
        }
        guard let key = KeychainStore.read(for: id.uuidString), !key.isEmpty else {
            phase = .error
            errorMessage = String(localized: "缺少 Web Key，请编辑该连接。")
            return
        }
        activeID = id
        activeName = name
        activeURL = url
        let client = MagpieAPIClient(baseURL: url, key: key)
        self.client = client
        phase = .loading
        errorMessage = nil
        do {
            try await client.signIn()
            state = try await client.send(.get("/api/state"), as: StateDTO.self)
            phase = .loaded
        } catch {
            phase = .error
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
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
    }
}