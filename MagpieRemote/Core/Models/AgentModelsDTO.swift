import Foundation

/// `GET /api/agent-models/{agentID}`：某个 Agent 的模型可见性列表。
struct AgentModelsResponseDTO: Codable, Sendable {
    var models: [AgentModelDTO]
    var ordered: [String]
    var only: Bool
    var ownHidden: Bool

    enum CodingKeys: String, CodingKey { case models, ordered, only, ownHidden }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.models = (try? c.decode([AgentModelDTO].self, forKey: .models)) ?? []
        self.ordered = (try? c.decode([String].self, forKey: .ordered)) ?? []
        self.only = (try? c.decode(Bool.self, forKey: .only)) ?? false
        self.ownHidden = (try? c.decode(Bool.self, forKey: .ownHidden)) ?? false
    }
}

struct AgentModelDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String?
    var group: String?
    var icon: String?
    var icons: [String]?
    var logo: String?
    var context: Int?
    var hidden: Bool?
    var inUse: Bool?
    var own: Bool?
    var kept: [String]?

    var displayName: String {
        guard let name, !name.isEmpty, name != id else { return id }
        return name
    }

    var isHidden: Bool { hidden ?? false }

    /// 所属分组（官方按 Provider 分组）。
    var groupName: String {
        guard let group, !group.isEmpty else { return String(localized: "其他") }
        return group
    }

    enum CodingKeys: String, CodingKey {
        case id, name, group, icon, icons, logo, context, hidden, inUse, own, kept
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? ""
        self.name = try? c.decodeIfPresent(String.self, forKey: .name)
        self.group = try? c.decodeIfPresent(String.self, forKey: .group)
        self.icon = try? c.decodeIfPresent(String.self, forKey: .icon)
        self.icons = try? c.decodeIfPresent([String].self, forKey: .icons)
        self.logo = try? c.decodeIfPresent(String.self, forKey: .logo)
        self.context = try? c.decodeIfPresent(Int.self, forKey: .context)
        self.hidden = try? c.decodeIfPresent(Bool.self, forKey: .hidden)
        self.inUse = try? c.decodeIfPresent(Bool.self, forKey: .inUse)
        self.own = try? c.decodeIfPresent(Bool.self, forKey: .own)
        self.kept = try? c.decodeIfPresent([String].self, forKey: .kept)
    }
}
