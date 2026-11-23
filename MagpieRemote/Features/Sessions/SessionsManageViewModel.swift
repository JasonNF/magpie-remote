import Foundation
import Observation

/// Sessions › 管理：录制开关、读取来源、按 Agent 删除、回收站恢复。
@Observable
@MainActor
final class SessionsManageViewModel {
    var data: SessionsManageDTO?
    var selectedAgent: String?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    var agents: [SessionManageAgentDTO] { data?.agents ?? [] }
    var sessions: [SessionManageItemDTO] { data?.sessions ?? [] }
    var trash: [SessionTrashDTO] { data?.trash ?? [] }
    var recording: Bool { data?.recording ?? false }
    var reads: SessionReadsDTO? { data?.reads }

    func load(client: MagpieAPIClient, agent: String? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let target = agent ?? selectedAgent ?? agents.first?.agent
        selectedAgent = target
        var path = "/api/sessions/manage"
        if let target, let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?agent=\(encoded)"
        }
        do {
            data = try await client.send(.get(path), as: SessionsManageDTO.self)
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }

    func setRecording(client: MagpieAPIClient, on: Bool) async {
        await post(client, path: "/api/sessions/recording", body: ["on": on])
    }

    func clearRecording(client: MagpieAPIClient) async {
        await post(client, path: "/api/sessions/recording", body: ["clear": true])
    }

    func setReads(client: MagpieAPIClient, all: Bool, agents: [String]) async {
        await post(client, path: "/api/sessions/reads", body: ["all": all, "agents": agents])
    }

    func delete(client: MagpieAPIClient, agent: String, ids: [String]) async {
        guard !ids.isEmpty else { return }
        await post(client, path: "/api/sessions/delete", body: ["agent": agent, "ids": ids])
    }

    func purgeAll(client: MagpieAPIClient) async {
        await post(client, path: "/api/sessions/purge", body: ["all": true])
    }

    func purge(client: MagpieAPIClient, keys: [String]) async {
        guard !keys.isEmpty else { return }
        await post(client, path: "/api/sessions/purge", body: ["keys": keys])
    }

    func restore(client: MagpieAPIClient, key: String) async {
        await post(client, path: "/api/sessions/restore", body: ["key": key])
    }

    @discardableResult
    private func post(_ client: MagpieAPIClient, path: String, body: [String: Any]) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let res = try await client.sendData(
                Endpoint(path: path, method: .post, body: try JSONSerialization.data(withJSONObject: body))
            )
            if let updated = try? JSONDecoder().decode(SessionsManageDTO.self, from: res),
               updated.agents != nil || updated.sessions != nil {
                data = updated
            }
            MagpieHaptics.light()
            return true
        } catch {
            errorMessage = APIError.message(for: error)
            return false
        }
    }
}
