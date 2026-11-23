import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var settings: SettingsDTO?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    func load(client: MagpieAPIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            self.settings = try await client.send(.get("/api/settings"), as: SettingsDTO.self)
        } catch {
            errorMessage = APIError.message(for: error)
        }
        isLoading = false
    }

    /// Claude Code 的提示词缓存时长（knob：cache_ttl / subagent_cache_ttl）。
    func setClaudeCache(client: MagpieAPIClient, knob: String, value: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            struct Body: Encodable {
                let Knob: String
                let Value: String
            }
            let updated: SettingsDTO = try await client.send(
                .post("/api/settings/claude-cache", body: Body(Knob: knob, Value: value)),
                as: SettingsDTO.self
            )
            settings = updated
            MagpieHaptics.success()
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }

    /// WebDAV 同步（官方 `/api/davsync`）：配置、立即同步、关闭、恢复。
    func davsync(client: MagpieAPIClient, action: String, body: [String: Any] = [:]) async -> JSONValue? {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = String(localized: "请求数据无效")
            return nil
        }
        do {
            let resData = try await client.sendData(
                Endpoint(path: "/api/davsync/\(action)", method: .post, body: data),
                timeout: 180
            )
            return try? JSONDecoder().decode(JSONValue.self, from: resData)
        } catch {
            errorMessage = APIError.message(for: error)
            return nil
        }
    }

    /// 官方 Settings 的「导出备份」：写到 magpie 所在机器的 Downloads。
    func exportBackup(
        client: MagpieAPIClient,
        passphrase: String,
        includeKeys: Bool,
        includeSignIns: Bool
    ) async -> BackupExportResultDTO? {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            struct Body: Encodable {
                let Pass: String
                let Keys: Bool
                let SignIns: Bool
            }
            return try await client.send(
                .post(
                    "/api/backup/export",
                    body: Body(Pass: passphrase, Keys: includeKeys, SignIns: includeSignIns)
                ),
                as: BackupExportResultDTO.self,
                timeout: 180
            )
        } catch {
            errorMessage = APIError.message(for: error)
            return nil
        }
    }

    func update<V: Encodable & Sendable>(client: MagpieAPIClient, key: String, value: V) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let dict: [String: AnyEncodable] = [key: AnyEncodable(value)]
            let data = try JSONEncoder().encode(dict)
            let endpoint = Endpoint(path: "/api/settings", method: .post, body: data)
            let updated = try await client.send(endpoint, as: SettingsDTO.self)
            self.settings = updated
        } catch {
            errorMessage = APIError.message(for: error)
        }
    }
}

/// 类型擦除的 Encodable 辅助结构
struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init<T: Encodable & Sendable>(_ wrapped: T) {
        _encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
