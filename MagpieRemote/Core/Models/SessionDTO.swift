import Foundation

/// magpie 历史会话记录
struct SessionDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var agent: String
    var name: String?
    var title: String?
    var cost: Double?
    var input: Int?
    var output: Int?
    var last: String?
    /// 官方 Carry：这段会话可以转换成的其他 Agent 会话。
    var carry: [SessionCarryDTO]?

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return id
    }

    /// 最近活动时间，换算成本地时区显示。不同 Agent 返回的时区不一样
    /// （omp 是 UTC 的 Z，claude / codex 带 +08:00），直接截字符串会同屏混用两种时区。
    var lastLocalText: String? {
        guard let last, !last.isEmpty else { return nil }
        guard let date = SharedFormatters.parseISOLenient(last) else {
            return String(last.prefix(16)).replacingOccurrences(of: "T", with: " ")
        }
        return SharedFormatters.localDateTime.string(from: date)
    }

    /// 最近活动日期（本地时区）。
    var lastLocalDay: String? {
        guard let text = lastLocalText else { return nil }
        return String(text.prefix(10))
    }

    /// 列表里的唯一标识。同一个会话 ID 会在多个 Agent 下各出现一条
    /// （例如 omp 经网关调用 Claude Code，两边都记了同一 ID），只用 `id` 会撞号，
    /// SwiftUI 会把撞号的那一行画成空白。调接口仍然用 `id`。
    var listID: String { "\(agent)/\(id)" }

    var displayAgent: String {
        name ?? agent
    }

    var formattedCost: String {
        guard let cost, cost > 0 else { return "$0.00" }
        return String(format: "$%.4f", cost)
    }

    var formattedTokens: String {
        let total = (input ?? 0) + (output ?? 0)
        return UsageDTO.formatTokens(total)
    }
}

/// 会话可以转成的其他 Agent（sessions.Session.Carry）。
struct SessionCarryDTO: Codable, Sendable, Hashable, Identifiable {
    var agent: String
    var command: String?
    /// 是否支持转换（Convert）；缺省按支持处理。
    var convert: Bool?

    var id: String { agent }
}

/// `POST /api/sessions/carry` 的返回。
struct SessionCarryResultDTO: Codable, Sendable {
    var agent: String?
    var id: String?
    var command: String?
}

/// `POST /api/sessions/export` 的返回（服务器 Downloads 里的路径）。
struct SessionExportResultDTO: Codable, Sendable {
    var path: String?
}

/// `GET /api/sessions` 响应体
struct SessionsResponseDTO: Codable, Sendable {
    var sessions: [SessionDTO]
}

/// 会话详细多轮对话记录 (Transcript)
struct TranscriptDTO: Codable, Sendable {
    var parts: [TranscriptPartDTO]
    var cut: Bool?
    var source: String?
}

/// 会话对话中的一个消息片段
struct TranscriptPartDTO: Codable, Sendable, Identifiable {
    var id: UUID = UUID()
    var role: String
    var kind: String
    var name: String?
    var text: String
    var cut: Int?

    enum CodingKeys: String, CodingKey {
        case role, kind, name, text, cut
    }
}
