import Foundation
import Observation

@Observable
@MainActor
final class SessionsViewModel {
    var sessions: [SessionDTO] = []
    var isLoading = false
    var errorMessage: String?

    func load(client: MagpieAPIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await client.send(.get("/api/sessions"), as: SessionsResponseDTO.self)
            self.sessions = res.sessions
            errorMessage = nil
        } catch where APIError.isCancellation(error) {
            // 被取消不是失败：保留现有列表和提示
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }

    /// 会话列表有 1.5 MB 左右，远程网络下要好几秒。下拉刷新或页面切走时 SwiftUI 会取消
    /// 调用方的任务，请求跟着作废，下次还得重下。这里放到独立任务里跑完，只是不再等它。
    func loadToCompletion(client: MagpieAPIClient) async {
        await Task { await self.load(client: client) }.value
    }

    /// 拉取指定会话的完整对话流与工具调用明细
    func fetchTranscript(client: MagpieAPIClient, agent: String, id: String) async -> TranscriptDTO? {
        do {
            let query = [
                URLQueryItem(name: "agent", value: agent),
                URLQueryItem(name: "id", value: id)
            ]
            return try await client.send(.get("/api/sessions/transcript", query: query), as: TranscriptDTO.self)
        } catch {
            return nil
        }
    }

    /// 官方「导出到服务器 Downloads」：`POST /api/sessions/export`。
    func exportMarkdown(client: MagpieAPIClient, agent: String, id: String) async -> String? {
        do {
            let query = [
                URLQueryItem(name: "agent", value: agent),
                URLQueryItem(name: "id", value: id)
            ]
            let res: SessionExportResultDTO = try await client.send(
                Endpoint(path: "/api/sessions/export", method: .post, query: query),
                as: SessionExportResultDTO.self
            )
            return res.path
        } catch {
            errorMessage = APIError.message(for: error)
            return nil
        }
    }

    /// 官方 Carry：把会话转换为另一个 Agent 的会话。
    func carry(client: MagpieAPIClient, agent: String, id: String, to: String) async -> SessionCarryResultDTO? {
        do {
            struct Body: Encodable {
                let Agent: String
                let ID: String
                let To: String
                let Open: Bool
            }
            return try await client.send(
                .post(
                    "/api/sessions/carry",
                    body: Body(Agent: agent, ID: id, To: to, Open: false)
                ),
                as: SessionCarryResultDTO.self
            )
        } catch {
            errorMessage = APIError.message(for: error)
            return nil
        }
    }

    /// 官方会话的 Markdown 导出（`/api/sessions/markdown`）。
    func fetchMarkdown(client: MagpieAPIClient, agent: String, id: String) async -> String? {
        do {
            let query = [
                URLQueryItem(name: "agent", value: agent),
                URLQueryItem(name: "id", value: id)
            ]
            let data = try await client.sendData(.get("/api/sessions/markdown", query: query))
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
