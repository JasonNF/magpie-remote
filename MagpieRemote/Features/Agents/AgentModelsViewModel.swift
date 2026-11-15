import Foundation
import Observation

/// per-Agent 模型可见性（官方 `/api/agent-models/{agentID}`）。
@Observable
@MainActor
final class AgentModelsViewModel {
    var models: [AgentModelDTO] = []
    var ordered: [String] = []
    var only = false
    var ownHidden = false
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    func load(client: MagpieAPIClient, agentID: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let res: AgentModelsResponseDTO = try await client.send(
                .get("/api/agent-models/\(agentID)"),
                as: AgentModelsResponseDTO.self,
                timeout: 60
            )
            apply(res)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setHidden(client: MagpieAPIClient, agentID: String, hidden: [String]) async {
        await post(client: client, agentID: agentID, body: ["hidden": hidden])
    }

    func setShown(client: MagpieAPIClient, agentID: String, shown: [String]) async {
        await post(client: client, agentID: agentID, body: ["shown": shown])
    }

    func setOnly(client: MagpieAPIClient, agentID: String, on: Bool) async {
        await post(client: client, agentID: agentID, body: ["only": on])
    }

    func setOwnHidden(client: MagpieAPIClient, agentID: String, on: Bool) async {
        await post(client: client, agentID: agentID, body: ["ownHidden": on])
    }

    func setOrder(client: MagpieAPIClient, agentID: String, order: [String]) async {
        await post(client: client, agentID: agentID, body: ["order": order])
    }

    /// 把被可见性设置挡住的模型重新放开。
    func widen(client: MagpieAPIClient, agentID: String, ids: [String]) async {
        await post(client: client, agentID: agentID, body: ["widen": ids])
    }

    /// 顺序视图中拖动后的本地更新。
    func moveOrder(from source: IndexSet, to destination: Int, visibleIDs: [String]) {
        var ids = orderedList(visibleIDs: visibleIDs)
        let moving = source.compactMap { ids.indices.contains($0) ? ids[$0] : nil }
        for index in source.sorted(by: >) where ids.indices.contains(index) {
            ids.remove(at: index)
        }
        let insertAt = destination - source.filter { $0 < destination }.count
        ids.insert(contentsOf: moving, at: min(max(insertAt, 0), ids.count))
        ordered = ids
    }

    /// 依 `ordered` 排序后的模型列表；未列出的按原顺序追加。
    func orderedList(visibleIDs: [String]) -> [String] {
        let byID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        var seen = Set<String>()
        var out: [String] = []
        for id in ordered where byID[id] != nil && !seen.contains(id) {
            out.append(id)
            seen.insert(id)
        }
        for model in models where !seen.contains(model.id) {
            out.append(model.id)
        }
        return out
    }

    private func post(client: MagpieAPIClient, agentID: String, body: [String: Any]) async {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = String(localized: "请求数据无效")
            return
        }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let resData = try await client.sendData(
                Endpoint(path: "/api/agent-models/\(agentID)", method: .post, body: data),
                timeout: 60
            )
            if let res = try? JSONDecoder().decode(AgentModelsResponseDTO.self, from: resData) {
                apply(res)
            } else {
                await load(client: client, agentID: agentID)
            }
            MagpieHaptics.light()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func apply(_ res: AgentModelsResponseDTO) {
        models = res.models
        ordered = res.ordered
        only = res.only
        ownHidden = res.ownHidden
    }
}
