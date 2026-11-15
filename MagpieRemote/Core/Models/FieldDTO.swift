import Foundation

/// magpie `fieldJSON`：Agent 的一个可配置字段（model / effort / opus / sonnet …）。
struct FieldDTO: Codable, Sendable, Identifiable, Hashable {
    var key: String
    var label: String
    var value: String
    /// 字段自带的选项；为 nil 时用 `list` 指向 `state.optionLists`。
    var options: [ModelOption]?
    /// 1 起索引，指向 `state.optionLists[list-1]`；0 表示用自带 `options`。
    var list: Int?

    var id: String { key }
}