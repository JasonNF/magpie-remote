import Foundation

/// magpie `agentJSON`：一个编码 Agent（Claude Code / Codex / Gemini CLI …）。
/// 仅建模核心字段，其余 `omitempty` 字段按需补充；Codable 自动忽略未知键。
struct AgentDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String
    var path: String?
    var fields: [FieldDTO]
    /// 用户自己的设置（如 Claude Code 的权限模式），单独折叠在「高级」里。
    var own: [FieldDTO]?
    /// magpie 已写入其配置。
    var wired: Bool?
    /// 配置被别的工具改写，需要重新应用。
    var drift: DriftDTO?
    /// 未接入时当前运行的来源。
    var source: String?
    /// 仍以旧模型列表运行的副本数。
    var stale: Int?
    /// 其菜单由这里挑选的模型组成（无单一启动模型）。
    var menu: Bool?
    var cliMissing: Bool?
    var command: String?
    var launch: String?
    var typed: String?
    var terminal: Bool?
    var openApp: Bool?
    /// 未接入但为账号故障转移仍走 magpie。
    var failover: Bool?
    /// 自带模型也接入（例如登录了 ChatGPT 的 Codex）。
    var joined: Bool?
    /// Codex 的 ChatGPT 额度用尽、暂时以 magpie 为提供方。
    var appOut: JSONValue?

    struct DriftDTO: Codable, Sendable, Hashable {
        var field: String?
        var want: String?
        var got: String?
    }
}