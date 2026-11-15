import Foundation

/// magpie `stateJSON`：App 的主数据源。几乎每次写操作后接口都返回最新 state。
struct StateDTO: Codable, Sendable {
    var agents: [AgentDTO]
    var clients: [ClientDTO]?
    var profiles: [ProfileDTO]?
    var catalog: String?
    var settings: SettingsDTO?
    var fx: FXDTO?
    var served: Int?
    var notice: String?
    /// 去重的模型选项池。
    var options: [ModelOption]?
    /// 每个字段引用的选项索引列表（1 起索引指向本数组）。
    var optionLists: [[Int]]?

    init(
        agents: [AgentDTO] = [],
        clients: [ClientDTO]? = nil,
        profiles: [ProfileDTO]? = nil,
        catalog: String? = nil,
        settings: SettingsDTO? = nil,
        fx: FXDTO? = nil,
        served: Int? = nil,
        notice: String? = nil,
        options: [ModelOption]? = nil,
        optionLists: [[Int]]? = nil
    ) {
        self.agents = agents
        self.clients = clients
        self.profiles = profiles
        self.catalog = catalog
        self.settings = settings
        self.fx = fx
        self.served = served
        self.notice = notice
        self.options = options
        self.optionLists = optionLists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agents = try container.decode([AgentDTO].self, forKey: .agents)
        self.clients = try? container.decodeIfPresent([ClientDTO].self, forKey: .clients)
        self.profiles = try? container.decodeIfPresent([ProfileDTO].self, forKey: .profiles)
        self.catalog = try? container.decodeIfPresent(String.self, forKey: .catalog)
        self.settings = try? container.decodeIfPresent(SettingsDTO.self, forKey: .settings)
        self.fx = try? container.decodeIfPresent(FXDTO.self, forKey: .fx)
        self.served = try? container.decodeIfPresent(Int.self, forKey: .served)
        self.notice = try? container.decodeIfPresent(String.self, forKey: .notice)
        self.options = try? container.decodeIfPresent([ModelOption].self, forKey: .options)
        self.optionLists = try? container.decodeIfPresent([[Int]].self, forKey: .optionLists)
    }

    /// 展开某字段的可选模型：`list` 指向共享池，否则用字段自带 options。
    func options(for field: FieldDTO) -> [ModelOption] {
        if let list = field.list, list > 0,
           let lists = optionLists, list - 1 < lists.count,
           let pool = options {
            return lists[list - 1].compactMap { index in
                index >= 0 && index < pool.count ? pool[index] : nil
            }
        }
        return field.options ?? []
    }
}