import Foundation
import Observation

// MARK: - 网关路由历史
/// `GET /api/gateway/history` 的返回。
struct GatewayHistoryDTO: Codable, Sendable {
    var days: [String]?
    var routes: [GatewayRouteDTO]?
    var cut: Bool?
    var tallies: GatewayTalliesDTO?

    enum CodingKeys: String, CodingKey { case days, routes, cut, tallies }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.days = try? c.decodeIfPresent([String].self, forKey: .days)
        self.routes = try? c.decodeIfPresent([GatewayRouteDTO].self, forKey: .routes)
        self.cut = try? c.decodeIfPresent(Bool.self, forKey: .cut)
        self.tallies = try? c.decodeIfPresent(GatewayTalliesDTO.self, forKey: .tallies)
    }
}

struct GatewayTalliesDTO: Codable, Sendable {
    var requests: Int?
    var rerouted: Int?
    var errors: Int?
    var tokens: Int?
}

/// `GET /api/gateway/trace`：网关此刻的实时路由决策。
struct GatewayTraceDTO: Codable, Sendable {
    var routes: [GatewayRouteDTO]?
    var mine: Bool?
    var now: String?

    enum CodingKeys: String, CodingKey { case routes, mine, now }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.routes = (try? c.decodeIfPresent([GatewayRouteDTO].self, forKey: .routes)) ?? []
        self.mine = try? c.decodeIfPresent(Bool.self, forKey: .mine)
        self.now = try? c.decodeIfPresent(String.self, forKey: .now)
    }
}

struct GatewayGroupRefDTO: Codable, Sendable, Hashable {
    var id: String
    var ref: String?
    var name: String?
    var routing: String?
    var affinity: String?
    var auto: Bool?
    var members: [String]?
    var via: [String]?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let ref, !ref.isEmpty { return ref }
        return id
    }
}

struct GatewayRouteDTO: Codable, Sendable, Identifiable, Hashable {
    var id: Int64
    var seq: Int64?
    var time: String?
    var agent: String?
    var model: String?
    var provider: String?
    var group: GatewayGroupRefDTO?
    var order: [GatewayWeighedDTO]?
    var done: Bool?
    var status: Int?
    var error: String?
    var canceled: Bool?
    var millis: Int64?
    var tokens: Int?
    var out: Int?
    var cost: Double?
    var priced: Bool?
    var kind: String?
    var callerKeyName: String?
    var session: String?
    var moved: GatewayMoveDTO?
    var served: String?

    var isError: Bool { !(error ?? "").isEmpty || ((status ?? 0) >= 400) }
    var isPending: Bool { done != true }

    var date: Date? {
        guard let time else { return nil }
        // ISO8601DateFormatter 不是 Sendable：按需创建，不共享静态实例。
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: time) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: time)
    }
}

struct GatewayMoveDTO: Codable, Sendable, Hashable {
    var to: String?
    var why: String?
}

struct GatewayWeighedDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var provider: String?
    var name: String?
    var icon: String?
    var who: String?
    var kind: String?
    var model: String?
    var fixed: String?
    var fast: Bool?
    var fallback: Bool?
    var used: Double?
    var known: Bool?

    var usedPercent: Int? {
        guard let used else { return nil }
        return Int((used * 100).rounded())
    }
}

// MARK: - ViewModel
@Observable
@MainActor
final class RoutingViewModel {
    var routes: [GatewayRouteDTO] = []
    /// 网关此刻还在进行中的请求（`/api/gateway/trace`）。
    var liveRoutes: [GatewayRouteDTO] = []
    var isLiveMine = false
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?

    private var refreshTask: Task<Void, Never>?
    private var traceTask: Task<Void, Never>?

    func load(client: MagpieAPIClient) async {
        do {
            let history: GatewayHistoryDTO = try await client.send(.get("/api/gateway/history"), as: GatewayHistoryDTO.self)
            routes = history.routes ?? []
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            if routes.isEmpty {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// 实时决策：`/api/gateway/trace`，2 秒一次，只保留进行中的请求。
    func loadTrace(client: MagpieAPIClient) async {
        do {
            let trace: GatewayTraceDTO = try await client.send(
                .get("/api/gateway/trace"),
                as: GatewayTraceDTO.self
            )
            isLiveMine = trace.mine ?? false
            liveRoutes = (trace.routes ?? []).filter { $0.isPending }
        } catch {
            // 实时轨迹失败不影响历史列表。
        }
    }

    /// 历史每 4 秒、实时轨迹每 2 秒各轮询一次；离开页面时取消。
    func startPolling(client: MagpieAPIClient) {
        stopPolling()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.load(client: client)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                if Task.isCancelled { break }
                await self.load(client: client)
            }
        }
        traceTask = Task { [weak self] in
            guard let self else { return }
            await self.loadTrace(client: client)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
                await self.loadTrace(client: client)
            }
        }
    }

    func stopPolling() {
        refreshTask?.cancel()
        refreshTask = nil
        traceTask?.cancel()
        traceTask = nil
    }

    var errorCount: Int {
        routes.filter { $0.isError }.count
    }

    var reroutedCount: Int {
        routes.filter { ($0.order?.count ?? 0) > 1 }.count
    }
}

// MARK: - 格式化
enum RoutingFormat {
    static func latency(_ millis: Int64?) -> String {
        guard let millis, millis > 0 else { return "—" }
        if millis >= 1000 {
            return String(format: "%.1fs", Double(millis) / 1000)
        }
        return "\(millis)ms"
    }

    static func tokens(_ count: Int?) -> String {
        guard let count else { return "—" }
        return UsageDTO.formatTokens(count)
    }

    static func cost(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value == 0 { return "$0" }
        if value < 0.01 { return String(format: "$%.4f", value) }
        return String(format: "$%.2f", value)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    static func statusText(_ route: GatewayRouteDTO) -> String {
        if route.canceled == true { return String(localized: "已取消") }
        if let status = route.status, status >= 400 { return "\(status)" }
        if route.isPending { return String(localized: "进行中") }
        return String(localized: "成功")
    }

    static func strategyName(_ value: String?) -> String {
        switch value {
        case "smart": return String(localized: "智能")
        case "order": return String(localized: "顺序")
        case "rotate": return String(localized: "轮询")
        case "usage": return String(localized: "用量")
        case "pace": return String(localized: "节奏")
        default: return value ?? "—"
        }
    }
}
