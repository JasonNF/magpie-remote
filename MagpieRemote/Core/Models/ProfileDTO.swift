import Foundation

/// magpie `profileJSON`：一套 Agent 配置快照。
struct ProfileDTO: Codable, Sendable, Identifiable, Hashable {
    var name: String
    var summary: String?
    var inUse: Bool?

    var id: String { name }
}