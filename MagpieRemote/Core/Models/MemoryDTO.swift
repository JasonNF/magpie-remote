import Foundation

/// 官方 Library › Memory（`internal/memory`）的模型。
/// Agent 通过 Magpie Memory MCP 服务检索与写入；带「指令」勾选的 Agent 读取其摘要。

/// `GET /api/memory` 的全量返回：记忆、项目名、摘要开关。
struct MemoryResponseDTO: Codable, Sendable {
    var memories: [MemoryDTO]?
    var projects: [String: MemoryProjectDTO]?
    var digest: Bool?
    /// 读取记忆摘要的 Agent id 列表。
    var agents: [String]?
    var suggestions: [MemorySuggestionDTO]?
    /// 服务端可能附带的问题说明（如存储不可用）。
    var problem: String?
}

struct MemoryProjectDTO: Codable, Sendable, Hashable {
    var name: String?
}

/// 一条记忆。
struct MemoryDTO: Codable, Sendable, Hashable, Identifiable {
    var id: String
    var text: String?
    var why: String?
    var tags: [String]?
    var kind: String?
    var scope: String?
    /// candidate（待确认）/ active / archived
    var status: String?
    var pinned: Bool?
    var created: String?
    var updated: String?
    var used: Int?

    enum CodingKeys: String, CodingKey {
        case id, text, why, tags, kind, scope, status, pinned, created, updated, used
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id 可能是字符串或数字
        if let s = try? c.decodeIfPresent(String.self, forKey: .id) {
            self.id = s
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .id) {
            self.id = String(i)
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "memory id")
            )
        }
        self.text = try? c.decodeIfPresent(String.self, forKey: .text)
        self.why = try? c.decodeIfPresent(String.self, forKey: .why)
        self.tags = try? c.decodeIfPresent([String].self, forKey: .tags)
        self.kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        self.scope = try? c.decodeIfPresent(String.self, forKey: .scope)
        self.status = try? c.decodeIfPresent(String.self, forKey: .status)
        self.pinned = try? c.decodeIfPresent(Bool.self, forKey: .pinned)
        self.created = try? c.decodeIfPresent(String.self, forKey: .created)
        self.updated = try? c.decodeIfPresent(String.self, forKey: .updated)
        self.used = try? c.decodeIfPresent(Int.self, forKey: .used)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(why, forKey: .why)
        try c.encodeIfPresent(tags, forKey: .tags)
        try c.encodeIfPresent(kind, forKey: .kind)
        try c.encodeIfPresent(scope, forKey: .scope)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(pinned, forKey: .pinned)
    }
}

/// 一条「建议记住」：Agent 猜到的记忆，等用户确认。
struct MemorySuggestionDTO: Codable, Sendable, Hashable {
    var key: String?
    var ids: [String]?
    var projects: [String]?
    var text: String?
    var kind: String?
}

/// `GET /api/memory/distill`：把对话读进记忆的蒸馏任务。
struct MemoryDistillDTO: Codable, Sendable, Hashable {
    var on: Bool?
    var model: String?
    var models: [MemoryDistillModelDTO]?
    /// 自动选择的模型 id。
    var auto: String?
    var effort: String?
    /// 当前模型实际生效的 effort（可能与 effort 不同）。
    var effortNow: String?
    var efforts: [String]?
    var days: Int?
    var ranges: [Int]?
    var running: Bool?
    var dreaming: Bool?
    var doing: Int?
    var of: Int?
    /// 尚未读取的会话数。
    var left: Int?
    var last: String?
    var added: Int?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case on, model, models, auto, effort, effortNow, efforts, days, ranges
        case running, dreaming, doing, of, left, last, added, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.on = try? c.decodeIfPresent(Bool.self, forKey: .on)
        self.model = try? c.decodeIfPresent(String.self, forKey: .model)
        self.models = try? c.decodeIfPresent([MemoryDistillModelDTO].self, forKey: .models)
        self.auto = try? c.decodeIfPresent(String.self, forKey: .auto)
        self.effort = try? c.decodeIfPresent(String.self, forKey: .effort)
        self.effortNow = try? c.decodeIfPresent(String.self, forKey: .effortNow)
        self.efforts = try? c.decodeIfPresent([String].self, forKey: .efforts)
        self.days = try? c.decodeIfPresent(Int.self, forKey: .days)
        self.ranges = try? c.decodeIfPresent([Int].self, forKey: .ranges)
        self.running = try? c.decodeIfPresent(Bool.self, forKey: .running)
        self.dreaming = try? c.decodeIfPresent(Bool.self, forKey: .dreaming)
        self.doing = try? c.decodeIfPresent(Int.self, forKey: .doing)
        self.of = try? c.decodeIfPresent(Int.self, forKey: .of)
        self.left = try? c.decodeIfPresent(Int.self, forKey: .left)
        self.last = try? c.decodeIfPresent(String.self, forKey: .last)
        self.added = try? c.decodeIfPresent(Int.self, forKey: .added)
        self.error = try? c.decodeIfPresent(String.self, forKey: .error)
    }

    init() {}
}

/// 蒸馏可选模型。
struct MemoryDistillModelDTO: Codable, Sendable, Hashable, Identifiable {
    var id: String?
    var name: String?
    var provider: String?
    var providerName: String?
    var icon: String?

    var displayName: String { name ?? id ?? "model" }
}

/// `GET /api/memory/semantic`：本地嵌入模型（memembed）的状态。
struct MemorySemanticDTO: Codable, Sendable, Hashable {
    var on: Bool?
    var installed: Bool?
    /// 模型体积（字节）。
    var size: Int?
    var downloading: Bool?
    var done: Int?
    var read: Int?
    var of: Int?
    var reading: Bool?
}

/// `GET /api/memory/rank?q=&status=`：按语义排序后的 id 列表。
struct MemoryRankDTO: Codable, Sendable, Hashable {
    var q: String?
    var status: String?
    var ids: [String]?
}

/// 记忆种类（官方 MEM_KINDS）。
enum MemoryKind: String, CaseIterable, Identifiable {
    case profile
    case preference
    case rule
    case reference
    case fact
    case procedure
    case episode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return String(localized: "关于你")
        case .preference: return String(localized: "偏好")
        case .rule: return String(localized: "规则")
        case .reference: return String(localized: "参考")
        case .fact: return String(localized: "事实")
        case .procedure: return String(localized: "做法")
        case .episode: return String(localized: "决策")
        }
    }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle"
        case .preference: return "heart"
        case .rule: return "checklist"
        case .reference: return "book"
        case .fact: return "lightbulb"
        case .procedure: return "list.number"
        case .episode: return "clock.arrow.circlepath"
        }
    }
}
