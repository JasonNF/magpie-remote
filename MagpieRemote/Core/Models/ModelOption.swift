import Foundation

/// magpie `agent.Option`：模型/字段的一个可选项。
/// `state.options[]` 去重存放，字段通过 `optionLists` 索引引用。
struct ModelOption: Codable, Sendable, Identifiable, Hashable {
    var value: String
    var label: String?
    var note: String?
    var takes: String?

    var id: String { value }

    /// 展示名：优先 label，否则 value；空 value 表示「默认/未设」。
    var displayName: String {
        if let label, !label.isEmpty { return label }
        return value.isEmpty ? String(localized: "默认") : value
    }
}