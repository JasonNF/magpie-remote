import Foundation

/// 整体用量统计摘要
struct UsageDTO: Codable, Sendable {
    var period: String?
    var since: String?
    var calls: Int?
    var errors: Int?
    var retried: Int?
    var canceled: Int?
    var input: Int?
    var output: Int?
    var cache_read: Int?
    var cache_write: Int?
    var reasoning: Int?
    var cost: Double?
    var unpriced: Int?
    var agents: [UsageGroupDTO]?
    var models: [UsageGroupDTO]?
    var accounts: [UsageGroupDTO]?
    var callerKeys: [UsageGroupDTO]?
    var path: String?

    var totalTokens: Int {
        (input ?? 0) + (output ?? 0) + (cache_read ?? 0)
    }

    var formattedCost: String {
        guard let cost else { return "$0.00" }
        return String(format: "$%.2f", cost)
    }

    var formattedCalls: String {
        guard let calls else { return "0" }
        return NumberFormatter.localizedString(from: NSNumber(value: calls), number: .decimal)
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.2f B", Double(count) / 1_000_000_000.0)
        } else if count >= 1_000_000 {
            return String(format: "%.2f M", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1f K", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}

/// `GET /api/usage/traffic`：网关累计收发字节与进行中的请求数。
struct UsageTrafficDTO: Codable, Sendable {
    var up: Int64?
    var down: Int64?
    var requests: Int?
}

/// `POST /api/usage/requests/export` 的返回：服务器 Downloads 里的 CSV 路径。
struct UsageExportResultDTO: Codable, Sendable {
    var path: String?
    var rows: Int?
}

/// 配额项详情（`GET /api/usage/quotas`）。
///
/// 字段语义以 Mac 端 magpie 的插件约定为准：
/// - `windows[].used` 是 0–100 的百分比；缺省表示插件没给，不是 0%。
/// - `amount` / `limit` / `unit` 是窗口自身的计数（如 WorkBuddy 的 credits）。
/// - `runsOutAt` / `runsOut`：最早一批剩余额度（如 WorkBuddy 积分包）何时失效、失效多少。
/// 每个字段都容错解码：任一账号多出或改了类型的字段不会拖垮整张列表。
struct QuotaItemDTO: Codable, Sendable, Identifiable, Hashable {
    var provider: String
    var name: String
    var user: String?
    var icon: String?
    var plan: String?
    var balance: String?
    var error: String?
    var readAt: String?
    var windows: [QuotaWindowDTO]?

    /// 同一 Provider 可能有多个账号，账号名必须参与标识，否则 ForEach 会收到重复 ID。
    var id: String { "\(provider)-\(name)-\(user ?? "")" }

    enum CodingKeys: String, CodingKey {
        case provider, name, user, icon, plan, balance, error, readAt, windows
    }

    init(
        provider: String,
        name: String,
        user: String? = nil,
        icon: String? = nil,
        plan: String? = nil,
        balance: String? = nil,
        error: String? = nil,
        readAt: String? = nil,
        windows: [QuotaWindowDTO]? = nil
    ) {
        self.provider = provider
        self.name = name
        self.user = user
        self.icon = icon
        self.plan = plan
        self.balance = balance
        self.error = error
        self.readAt = readAt
        self.windows = windows
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = (try? c.decode(String.self, forKey: .provider)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? provider
        user = QuotaDecoding.string(c, .user)
        icon = QuotaDecoding.string(c, .icon)
        plan = QuotaDecoding.string(c, .plan)
        balance = QuotaDecoding.string(c, .balance)
        error = QuotaDecoding.string(c, .error)
        readAt = QuotaDecoding.string(c, .readAt)
        if let raw = try? c.decodeIfPresent([QuotaDecoding.Lossy<QuotaWindowDTO>].self, forKey: .windows) {
            windows = raw.compactMap(\.value)
        } else {
            windows = nil
        }
    }

    /// 卡片头部的积分摘要：优先「Total credits」，否则唯一的积分窗口。
    var creditSummaryWindow: QuotaWindowDTO? {
        let credits = (windows ?? []).filter(\.isCreditCount)
        if let total = credits.first(where: { $0.name.lowercased().contains("total") }) { return total }
        return credits.count == 1 ? credits.first : nil
    }

    /// 没有任何可展示的额度数据（读取失败或尚未读到）。
    var hasNoData: Bool {
        (windows ?? []).isEmpty && (balance ?? "").isEmpty
    }

    struct QuotaWindowDTO: Codable, Sendable, Identifiable, Hashable {
        var name: String
        /// 0–100 的百分比；nil 表示未知。
        var used: Double?
        var remaining: Double?
        var resetsAt: String?
        var startsAt: String?
        var display: String?
        /// 已用数量（单位见 `unit`）。
        var amount: Double?
        var limit: Double?
        var unit: String?
        /// 无总量的预付余额（单位见 `unit`）。
        var balance: Double?
        /// 最早一批剩余额度失效的时间与数量。
        var runsOutAt: String?
        var runsOut: Double?
        /// 用完也不会停用账号。
        var aside: Bool?

        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name, used, remaining, resetsAt, startsAt, display, amount, limit, unit
            case balance, runsOutAt, runsOut, aside
        }

        init(
            name: String,
            used: Double? = nil,
            remaining: Double? = nil,
            resetsAt: String? = nil,
            startsAt: String? = nil,
            display: String? = nil,
            amount: Double? = nil,
            limit: Double? = nil,
            unit: String? = nil,
            balance: Double? = nil,
            runsOutAt: String? = nil,
            runsOut: Double? = nil,
            aside: Bool? = nil
        ) {
            self.name = name
            self.used = used
            self.remaining = remaining
            self.resetsAt = resetsAt
            self.startsAt = startsAt
            self.display = display
            self.amount = amount
            self.limit = limit
            self.unit = unit
            self.balance = balance
            self.runsOutAt = runsOutAt
            self.runsOut = runsOut
            self.aside = aside
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // 没有名字的窗口无法展示，交给 Lossy 丢弃
            name = try c.decode(String.self, forKey: .name)
            used = QuotaDecoding.number(c, .used)
            remaining = QuotaDecoding.number(c, .remaining)
            resetsAt = QuotaDecoding.time(c, .resetsAt)
            startsAt = QuotaDecoding.time(c, .startsAt)
            display = QuotaDecoding.string(c, .display)
            amount = QuotaDecoding.number(c, .amount)
            limit = QuotaDecoding.number(c, .limit)
            unit = QuotaDecoding.string(c, .unit)
            balance = QuotaDecoding.number(c, .balance)
            runsOutAt = QuotaDecoding.time(c, .runsOutAt)
            runsOut = QuotaDecoding.number(c, .runsOut)
            aside = try? c.decodeIfPresent(Bool.self, forKey: .aside)
        }

        // MARK: 百分比

        /// 是否给出了占比（`used` 缺省表示未知）。
        var hasPercent: Bool { used != nil }

        /// 已用百分比，0–100。服务端约定 `used` 本身就是百分比，不能按小数放大。
        var percentUsed: Double {
            guard let used, used.isFinite else { return 0 }
            return min(max(used, 0), 100)
        }

        /// 极小占比也要可读：0.09% 不能显示成 0%，更不能显示成 9%。
        var percentText: String {
            guard hasPercent else { return "—" }
            let p = percentUsed
            if p == 0 { return "0%" }
            if p < 0.1 { return "<0.1%" }
            if p < 10 { return String(format: "%.1f%%", p) }
            return String(format: "%.0f%%", p)
        }

        // MARK: 计数（积分）

        /// 按数量计的窗口（有总量），如 WorkBuddy credits。
        var isCreditCount: Bool {
            guard let limit, limit > 0 else { return false }
            return (unit ?? "").lowercased() == "credits"
        }

        /// 已用数量：优先服务端给的 `amount`，否则用百分比折算。
        var usedAmount: Double? {
            if let amount { return amount }
            guard let limit, limit > 0, let used else { return nil }
            return limit * min(max(used, 0), 100) / 100
        }

        /// 剩余数量。
        var leftAmount: Double? {
            guard let limit, limit > 0, let usedAmount else { return nil }
            return max(limit - usedAmount, 0)
        }

        /// 本地化的单位名。
        var unitLabel: String {
            switch (unit ?? "").lowercased() {
            case "credits", "credit": return String(localized: "积分")
            case "tokens", "token": return "Token"
            case "": return ""
            default: return unit ?? ""
            }
        }

        /// 「已用 / 总量」，如「6.04 / 6,835」。没有总量时退回服务端的 `display`。
        var countText: String? {
            if let limit, limit > 0, let usedAmount, isCreditCount {
                return "\(QuotaFormat.amount(usedAmount)) / \(QuotaFormat.amount(limit))"
            }
            if let display, !display.isEmpty, display.lowercased() != "unknown" { return display }
            if let balance { return "\(QuotaFormat.amount(balance)) \(unitLabel)".trimmingCharacters(in: .whitespaces) }
            return nil
        }

        /// 窗口名中文化（WorkBuddy 的几种积分窗口）；其他窗口保持原名。
        var displayName: String {
            switch name.lowercased() {
            case "credits": return String(localized: "月度积分")
            case "extra credits": return String(localized: "额外积分")
            case "total credits": return String(localized: "积分合计")
            default:
                if name.hasSuffix(" tokens (est.)") {
                    let model = name.dropLast(" tokens (est.)".count)
                    return String(localized: "\(String(model)) Token（估算）")
                }
                return name
            }
        }

        /// 将要失效的额度（积分包到期），过期时间已过则忽略。
        var expiringSoon: (amount: Double, date: Date)? {
            guard let runsOut, runsOut > 0, let date = QuotaFormat.date(runsOutAt), date > Date() else { return nil }
            return (runsOut, date)
        }
    }
}

/// 配额字段的容错解码。
enum QuotaDecoding {
    struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    static func string<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return QuotaFormat.amount(d) }
        return nil
    }

    static func number<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }

    /// 时间可能是 ISO 字符串，也可能是毫秒时间戳；统一转成 ISO 字符串。
    static func time<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let ms = try? c.decodeIfPresent(Double.self, forKey: key) {
            return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: ms / 1000))
        }
        return nil
    }
}

/// 配额数字与时间的展示格式。
enum QuotaFormat {
    /// 整数不带小数，小数最多两位，带千分位：6835 → "6,835"，6828.96 → "6,828.96"。
    /// 不对大数取整：剩余积分四舍五入会多报额度。
    static func amount(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func date(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = frac.date(from: raw) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: raw) { return d }
        if let ms = Double(raw) { return Date(timeIntervalSince1970: ms / 1000) }
        return nil
    }

    /// 本地时间的短格式：同年省略年份，如「11/30 23:59」。
    static func shortDate(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate(
            cal.component(.year, from: date) == cal.component(.year, from: now) ? "MMdHHmm" : "yyyyMMdHHmm"
        )
        return f.string(from: date)
    }

    /// 原始时间字符串转短格式，解析失败时原样返回。
    static func shortDate(_ raw: String) -> String {
        guard let d = date(raw) else { return raw }
        return shortDate(d)
    }
}

// MARK: - Overview 分组
/// `/api/usage` 的 agents / models / accounts / callerKeys 行。
struct UsageGroupDTO: Codable, Sendable, Identifiable {
    var rawID: String?
    var name: String?
    var sub: String?
    var icon: String?
    var model: String?
    var provider: String?
    var account: String?
    var callerKeyId: String?
    var calls: Int?
    var input: Int?
    var output: Int?
    var cacheRead: Int?
    var cacheWrite: Int?
    var cost: Double?
    var unpriced: Int?
    var tokens: Int?

    var id: String {
        [rawID, name, model, account, callerKeyId, provider]
            .compactMap { $0 }
            .joined(separator: "|")
    }

    var totalTokens: Int {
        tokens ?? ((input ?? 0) + (output ?? 0) + (cacheRead ?? 0) + (cacheWrite ?? 0))
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let model, !model.isEmpty { return model }
        if let account, !account.isEmpty { return account }
        return rawID ?? "—"
    }

    var formattedCost: String {
        guard let cost else { return "—" }
        return cost < 0.01 ? String(format: "$%.4f", cost) : String(format: "$%.2f", cost)
    }

    enum CodingKeys: String, CodingKey {
        case rawID = "id"
        case name, sub, icon, model, provider, account, callerKeyId
        case calls, input, output
        case cacheRead = "cache_read"
        case cacheWrite = "cache_write"
        case cost, unpriced, tokens
    }
}

// MARK: - Requests 账本
struct UsageLedgerDTO: Codable, Sendable {
    var rows: [UsageLedgerRowDTO]?
    var total: Int?
    var offset: Int?
    var bucket: String?
    var day: String?
    var period: String?
    var calls: Int?
    var input: Int?
    var output: Int?
    var cacheRead: Int?
    var cacheWrite: Int?
    var cost: Double?
    var unpriced: Int?
    var agents: [UsageNamedDTO]?
    var providers: [UsageNamedDTO]?
    var accounts: [UsageAccountDTO]?
    var callerKeys: [UsageGroupDTO]?

    enum CodingKeys: String, CodingKey {
        case rows, total, offset, bucket, day, period
        case calls, input, output
        case cacheRead = "cache_read"
        case cacheWrite = "cache_write"
        case cost, unpriced, agents, providers, accounts, callerKeys
    }
}

struct UsageLedgerRowDTO: Codable, Sendable, Identifiable {
    var routeId: Int64?
    var time: String?
    var agent: String?
    var agentName: String?
    var icon: String?
    var provider: String?
    var providerName: String?
    var model: String?
    var requested: String?
    var session: String?
    var input: Int?
    var output: Int?
    var cacheRead: Int?
    var cacheWrite: Int?
    var cost: Double?
    var priced: Bool?
    var status: Int?
    var error: String?
    var millis: Int64?
    var source: String?
    var callerKeyId: String?
    var callerKeyLabel: String?
    var access: String?
    var canceled: Bool?

    var id: String {
        "\(routeId ?? 0)-\(time ?? "")-\(model ?? "")-\(input ?? 0)"
    }

    var isError: Bool {
        (!(error ?? "").isEmpty && canceled != true)
            || ((status ?? 0) >= 400 && canceled != true)
    }

    var totalTokens: Int {
        (input ?? 0) + (output ?? 0) + (cacheRead ?? 0) + (cacheWrite ?? 0)
    }

    var displayAgent: String { agentName ?? agent ?? "—" }

    var displayProvider: String { providerName ?? provider ?? "—" }

    var formattedCost: String {
        guard let cost else { return "—" }
        return cost < 0.01 ? String(format: "$%.4f", cost) : String(format: "$%.2f", cost)
    }

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case time = "t"
        case agent, agentName, icon, provider, providerName, model
        case requested = "req"
        case session
        case input = "in"
        case output = "out"
        case cacheRead = "cache_read"
        case cacheWrite = "cache_write"
        case cost, priced, status
        case error = "err"
        case millis = "ms"
        case source
        case callerKeyId, callerKeyLabel, access, canceled
    }
}

struct UsageNamedDTO: Codable, Sendable, Identifiable {
    var id: String
    var name: String?
    var icon: String?

    var displayName: String { (name?.isEmpty == false ? name! : id) }
}

struct UsageAccountDTO: Codable, Sendable, Identifiable {
    var id: String
    var name: String?
    var providers: [String]?

    var displayName: String { (name?.isEmpty == false ? name! : id) }
}

// MARK: - Heatmap
struct UsageHeatmapDTO: Codable, Sendable {
    var from: String?
    var to: String?
    var days: [UsageHeatDayDTO]?

    enum CodingKeys: String, CodingKey { case from, to, days }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.from = try? c.decodeIfPresent(String.self, forKey: .from)
        self.to = try? c.decodeIfPresent(String.self, forKey: .to)
        self.days = (try? c.decode([UsageHeatDayDTO].self, forKey: .days)) ?? []
    }
}

struct UsageHeatDayDTO: Codable, Sendable, Identifiable {
    var date: String
    var calls: Int?
    var tokens: Int?
    var cost: Double?
    var unpriced: Int?

    var id: String { date }
}

// MARK: - Context
struct UsageContextDTO: Codable, Sendable {
    var days: Int?
    var agents: [UsageContextAgentDTO]?

    enum CodingKeys: String, CodingKey { case days, agents }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.days = try? c.decodeIfPresent(Int.self, forKey: .days)
        self.agents = (try? c.decode([UsageContextAgentDTO].self, forKey: .agents)) ?? []
    }
}

struct UsageContextAgentDTO: Codable, Sendable, Identifiable {
    var agent: String
    var requests: Int?
    var sessions: Int?
    var errors: Int?
    var calls: Int?
    var median: Int?
    var p90: Int?
    var baseline: Int?
    var window: Int?
    var cache: Double?
    var growth: Int?
    var peakFill: Double?
    var compacts: Int?
    var score: Int?
    var models: [String]?
    var tags: [UsageContextTagDTO]?
    var latestId: Int64?

    var id: String { agent }

    enum CodingKeys: String, CodingKey {
        case agent, requests, sessions, errors, calls, median, p90, baseline, window
        case cache, growth, peakFill, compacts, score, models, tags, latestId
    }
}

struct UsageContextTagDTO: Codable, Sendable, Identifiable, Hashable {
    var key: String
    var tone: String?
    var value: Double?

    var id: String { key + (tone ?? "") }
}


