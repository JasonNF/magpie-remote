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
        errorMessage = nil
        do {
            let res = try await client.send(.get("/api/sessions"), as: SessionsResponseDTO.self)
            self.sessions = res.sessions
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
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
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
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
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
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
