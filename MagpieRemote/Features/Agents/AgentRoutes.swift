import Foundation

/// Agents 导航路由（按 id 引用，确保读取的是最新 state）。
struct AgentRoute: Hashable {
    let id: String
}

/// 模型/字段选择器路由。
struct PickerRoute: Hashable {
    let agentID: String
    let fieldKey: String
}