import Foundation

/// `POST /api/set` 请求体。注意 magpie 的 JSON 键为首字母大写（Go 字段名）。
struct SetRequest: Encodable, Sendable {
    let agent: String
    let field: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case agent = "Agent"
        case field = "Field"
        case value = "Value"
    }
}