import Foundation
import Observation

/// Library › Memory：记忆的读取、编辑、状态流转与蒸馏/语义检索设置。
@Observable
@MainActor
final class MemoryViewModel {
    var data: MemoryResponseDTO?
    var distill: MemoryDistillDTO?
    var semantic: MemorySemanticDTO?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    /// 语义排序后的 id 顺序（`/api/memory/rank`）。
    var rankedIDs: [String] = []

    var memories: [MemoryDTO] { data?.memories ?? [] }
    var projects: [String: MemoryProjectDTO] { data?.projects ?? [:] }
    var digestOn: Bool { data?.digest ?? false }

    func load(client: MagpieAPIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            data = try await client.send(.get("/api/memory"), as: MemoryResponseDTO.self)
            if let problem = data?.problem, !problem.isEmpty {
                errorMessage = problem
            }
        } catch {
            errorMessage = APIError.message(for: error)
        }
        isLoading = false
    }

    /// 记忆写入：新建或更新（带 id）。返回是否成功。
    @discardableResult
    func save(
        client: MagpieAPIClient,
        id: String?,
        text: String,
        why: String,
        tags: String,
        kind: String,
        scope: String
    ) async -> Bool {
        var body: [String: Any] = [
            "text": text,
            "why": why,
            "tags": tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty },
            "kind": kind,
            "scope": scope
        ]
        if let id {
            body["id"] = id
        }
        return await post(client, path: "/api/memory", body: body)
    }

    func setStatus(client: MagpieAPIClient, id: String, status: String) async {
        await post(client, path: "/api/memory", body: ["id": id, "status": status])
    }

    func togglePin(client: MagpieAPIClient, memory: MemoryDTO) async {
        await post(client, path: "/api/memory", body: ["id": memory.id, "pinned": !(memory.pinned ?? false)])
    }

    func remove(client: MagpieAPIClient, ids: [String]) async {
        guard !ids.isEmpty else { return }
        await post(client, path: "/api/memory/remove", body: ["ids": ids])
    }

    func promote(client: MagpieAPIClient, ids: [String]) async {
        guard !ids.isEmpty else { return }
        await post(client, path: "/api/memory/promote", body: ["ids": ids])
    }

    func decline(client: MagpieAPIClient, key: String) async {
        await post(client, path: "/api/memory/decline", body: ["key": key])
    }

    func makeSkill(client: MagpieAPIClient, id: String) async {
        await post(client, path: "/api/memory/skill", body: ["id": id])
    }

    func setDigest(client: MagpieAPIClient, on: Bool) async {
        await post(client, path: "/api/memory/digest", body: ["on": on])
    }

    // MARK: - 蒸馏

    func loadDistill(client: MagpieAPIClient) async {
        distill = try? await client.send(.get("/api/memory/distill"), as: MemoryDistillDTO.self)
    }

    func setDistill(client: MagpieAPIClient, on: Bool, model: String, effort: String? = nil, days: Int? = nil) async {
        var body: [String: Any] = ["on": on, "model": model]
        if let effort { body["effort"] = effort }
        if let days { body["days"] = days }
        isSaving = true
        defer { isSaving = false }
        do {
            let res = try await client.sendData(
                Endpoint(path: "/api/memory/distill", method: .post, body: try JSONSerialization.data(withJSONObject: body))
            )
            distill = try? JSONDecoder().decode(MemoryDistillDTO.self, from: res)
            MagpieHaptics.success()
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }

    func runDistill(client: MagpieAPIClient) async {
        await postDistill(client, path: "/api/memory/distill/run")
    }

    func stopDistill(client: MagpieAPIClient) async {
        await postDistill(client, path: "/api/memory/distill/stop")
    }

    private func postDistill(_ client: MagpieAPIClient, path: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let res = try await client.sendData(
                Endpoint(path: path, method: .post, body: Data("{}".utf8))
            )
            distill = try? JSONDecoder().decode(MemoryDistillDTO.self, from: res)
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }

    // MARK: - 语义检索

    func loadSemantic(client: MagpieAPIClient) async {
        semantic = try? await client.send(.get("/api/memory/semantic"), as: MemorySemanticDTO.self)
    }

    func setSemantic(client: MagpieAPIClient, on: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let res = try await client.sendData(
                Endpoint(
                    path: "/api/memory/semantic",
                    method: .post,
                    body: try JSONSerialization.data(withJSONObject: ["on": on])
                )
            )
            semantic = try? JSONDecoder().decode(MemorySemanticDTO.self, from: res)
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }

    /// 按语义给记忆排序；失败时保持原顺序。
    func rank(client: MagpieAPIClient, query: String, status: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            rankedIDs = []
            return
        }
        var comps = URLComponents()
        comps.path = "/api/memory/rank"
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "status", value: status)
        ]
        guard let path = comps.string else { return }
        if let res = try? await client.send(.get(path), as: MemoryRankDTO.self) {
            rankedIDs = res.ids ?? []
        }
    }

    // MARK: - 通用

    @discardableResult
    private func post(_ client: MagpieAPIClient, path: String, body: [String: Any]) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let res = try await client.sendData(
                Endpoint(path: path, method: .post, body: try JSONSerialization.data(withJSONObject: body))
            )
            data = try? JSONDecoder().decode(MemoryResponseDTO.self, from: res)
            if let problem = data?.problem, !problem.isEmpty {
                errorMessage = problem
            }
            MagpieHaptics.light()
            return true
        } catch {
            errorMessage = APIError.message(for: error)
            return false
        }
    }
}
