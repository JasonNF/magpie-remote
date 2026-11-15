import Foundation
import Observation

// MARK: - Pi 扩展（`/api/library/pi`）
/// `GET /api/library/pi`：每台 Pi 加载的扩展与包。
struct PiViewDTO: Codable, Sendable {
    var pis: [PiDTO]

    enum CodingKeys: String, CodingKey { case pis }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pis = (try? c.decode([PiDTO].self, forKey: .pis)) ?? []
    }
}

struct PiDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var dir: String?
    var wsl: String?
    var asleep: Bool?
    var err: String?
    var extensions: [PiExtensionDTO]?
    var packages: [PiPackageDTO]?
}

struct PiExtensionDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String?
    var path: String?
    var on: Bool?

    var displayName: String { name ?? id }
}

struct PiPackageDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String { source }
    var source: String
    var name: String?
    var kind: String?
    var version: String?
    var on: Bool?
    var installed: Bool?
    var filtered: Bool?
}

// MARK: - RTK（`/api/library/rtk`）
struct RTKViewDTO: Codable, Sendable {
    var path: String?
    var version: String?
    var latest: String?
    var waiting: String?
    var waitingHas: String?
    var upgrade: String?
    var admin: Bool?
    var pathDir: String?
    var pathLink: Bool?
    var offPath: Bool?
    var agents: [RTKAgentDTO]?
    var gain: RTKGainDTO?

    enum CodingKeys: String, CodingKey {
        case path, version, latest, waiting, waitingHas, upgrade, admin
        case pathDir, pathLink, offPath, agents, gain
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try? c.decodeIfPresent(String.self, forKey: .path)
        self.version = try? c.decodeIfPresent(String.self, forKey: .version)
        self.latest = try? c.decodeIfPresent(String.self, forKey: .latest)
        self.waiting = try? c.decodeIfPresent(String.self, forKey: .waiting)
        self.waitingHas = try? c.decodeIfPresent(String.self, forKey: .waitingHas)
        self.upgrade = try? c.decodeIfPresent(String.self, forKey: .upgrade)
        self.admin = try? c.decodeIfPresent(Bool.self, forKey: .admin)
        self.pathDir = try? c.decodeIfPresent(String.self, forKey: .pathDir)
        self.pathLink = try? c.decodeIfPresent(Bool.self, forKey: .pathLink)
        self.offPath = try? c.decodeIfPresent(Bool.self, forKey: .offPath)
        self.agents = try? c.decodeIfPresent([RTKAgentDTO].self, forKey: .agents)
        self.gain = try? c.decodeIfPresent(RTKGainDTO.self, forKey: .gain)
    }
}

struct RTKAgentDTO: Codable, Sendable, Identifiable, Hashable {
    var agent: String
    var on: Bool?

    var id: String { agent }
}

struct RTKGainDTO: Codable, Sendable {
    var calls: Int?
    var tokens: Int?
    var cost: Double?

    enum CodingKeys: String, CodingKey { case calls, tokens, cost }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.calls = try? c.decodeIfPresent(Int.self, forKey: .calls)
        self.tokens = try? c.decodeIfPresent(Int.self, forKey: .tokens)
        self.cost = try? c.decodeIfPresent(Double.self, forKey: .cost)
    }
}

// MARK: - billion-context（`/api/library/bili`）
struct BiliViewDTO: Codable, Sendable {
    var path: String?
    var version: String?
    var url: String?
    var install: String?
    var listErr: String?
    var saved: BiliSavedDTO?
    var restart: [String]?
    var agents: [BiliAgentDTO]?

    enum CodingKeys: String, CodingKey {
        case path, version, url, install, listErr, saved, restart, agents
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try? c.decodeIfPresent(String.self, forKey: .path)
        self.version = try? c.decodeIfPresent(String.self, forKey: .version)
        self.url = try? c.decodeIfPresent(String.self, forKey: .url)
        self.install = try? c.decodeIfPresent(String.self, forKey: .install)
        self.listErr = try? c.decodeIfPresent(String.self, forKey: .listErr)
        self.saved = try? c.decodeIfPresent(BiliSavedDTO.self, forKey: .saved)
        self.restart = try? c.decodeIfPresent([String].self, forKey: .restart)
        self.agents = try? c.decodeIfPresent([BiliAgentDTO].self, forKey: .agents)
    }
}

struct BiliAgentDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String?
    var on: Bool?
    var status: String?

    var isOn: Bool { on ?? false }
    var isPartial: Bool { status?.isEmpty == false }
}

struct BiliSavedDTO: Codable, Sendable {
    var hasFolds: Bool?
    var net: Int64?
    var gross: Int64?
    var folds: Int?
    var sessions: Int?
    var requests: Int?
    var live: Bool?
    var at: String?

    enum CodingKeys: String, CodingKey {
        case hasFolds, net, gross, folds, sessions, requests, live, at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hasFolds = try? c.decodeIfPresent(Bool.self, forKey: .hasFolds)
        self.net = try? c.decodeIfPresent(Int64.self, forKey: .net)
        self.gross = try? c.decodeIfPresent(Int64.self, forKey: .gross)
        self.folds = try? c.decodeIfPresent(Int.self, forKey: .folds)
        self.sessions = try? c.decodeIfPresent(Int.self, forKey: .sessions)
        self.requests = try? c.decodeIfPresent(Int.self, forKey: .requests)
        self.live = try? c.decodeIfPresent(Bool.self, forKey: .live)
        self.at = try? c.decodeIfPresent(String.self, forKey: .at)
    }
}

// MARK: - ViewModel
@Observable
@MainActor
final class PiRTKViewModel {
    var piView: PiViewDTO?
    var rtk: RTKViewDTO?
    var bili: BiliViewDTO?
    var isLoading = false
    var isWorking = false
    var errorMessage: String?

    // MARK: Pi
    func loadPi(client: MagpieAPIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            piView = try await client.send(.get("/api/library/pi"), as: PiViewDTO.self)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 开关某个扩展或包（body: { pi, ext|pkg, on }）。
    func setPiEntry(
        client: MagpieAPIClient,
        pi: String,
        extensionID: String? = nil,
        packageSource: String? = nil,
        on: Bool
    ) async {
        await mutate(client: client, path: "/api/library/pi") { body in
            body["pi"] = pi
            if let extensionID { body["ext"] = extensionID }
            if let packageSource { body["pkg"] = packageSource }
            body["on"] = on
        }
    }

    /// 把扩展/包复制到另一台 Pi。
    func copyPiEntry(
        client: MagpieAPIClient,
        from: String,
        to: String,
        extensionID: String? = nil,
        packageSource: String? = nil
    ) async {
        await mutate(client: client, path: "/api/library/pi/copy") { body in
            body["from"] = from
            body["to"] = to
            if let extensionID { body["ext"] = extensionID }
            if let packageSource { body["pkg"] = packageSource }
        }
    }

    /// 从 Pi 市场安装包到某台 Pi。
    func installPiPackage(client: MagpieAPIClient, pi: String, source: String) async {
        await mutate(client: client, path: "/api/library/pi/install") { body in
            body["pi"] = pi
            body["source"] = source
        }
    }

    func removePiPackage(client: MagpieAPIClient, pi: String, source: String) async {
        await mutate(client: client, path: "/api/library/pi/remove") { body in
            body["pi"] = pi
            body["source"] = source
        }
    }

    // MARK: RTK
    func loadRTK(client: MagpieAPIClient) async {
        do {
            rtk = try await client.send(.get("/api/library/rtk"), as: RTKViewDTO.self)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setRTK(client: MagpieAPIClient, agent: String, on: Bool) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            struct Body: Encodable { let agent: String; let on: Bool }
            let resData = try await client.sendData(
                try Endpoint.post("/api/library/rtk", body: Body(agent: agent, on: on))
            )
            if let updated = try? JSONDecoder().decode(RTKViewDTO.self, from: resData) {
                rtk = updated
            }
            MagpieHaptics.light()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func upgradeRTK(client: MagpieAPIClient) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let resData = try await client.sendData(
                Endpoint.post("/api/library/rtk/upgrade"),
                timeout: 180
            )
            if let updated = try? JSONDecoder().decode(RTKViewDTO.self, from: resData) {
                rtk = updated
            }
            MagpieHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func pathRTK(client: MagpieAPIClient) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let resData = try await client.sendData(
                Endpoint.post("/api/library/rtk/path"),
                timeout: 180
            )
            if let updated = try? JSONDecoder().decode(RTKViewDTO.self, from: resData) {
                rtk = updated
            }
            MagpieHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: billion-context
    func loadBili(client: MagpieAPIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            bili = try await client.send(.get("/api/library/bili"), as: BiliViewDTO.self)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 给某 Agent 开/关 billion-context（body: { agent, on }）。
    func setBili(client: MagpieAPIClient, agent: String, on: Bool) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            struct Body: Encodable { let agent: String; let on: Bool }
            let resData = try await client.sendData(
                try Endpoint.post("/api/library/bili", body: Body(agent: agent, on: on)),
                timeout: 180
            )
            if let updated = try? JSONDecoder().decode(BiliViewDTO.self, from: resData) {
                bili = updated
            }
            MagpieHaptics.light()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 安装 billion-context。
    func installBili(client: MagpieAPIClient) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let resData = try await client.sendData(
                Endpoint.post("/api/library/bili/install"),
                timeout: 300
            )
            if let updated = try? JSONDecoder().decode(BiliViewDTO.self, from: resData) {
                bili = updated
            }
            MagpieHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func mutate(client: MagpieAPIClient, path: String, configure: (inout [String: Any]) -> Void) async {
        var body: [String: Any] = [:]
        configure(&body)
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = String(localized: "请求数据无效")
            return
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let resData = try await client.sendData(
                Endpoint(path: path, method: .post, body: data),
                timeout: 180
            )
            if let updated = try? JSONDecoder().decode(PiViewDTO.self, from: resData) {
                piView = updated
            }
            MagpieHaptics.light()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
