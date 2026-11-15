import Foundation

/// magpie `clientJSON`：可能发起请求的客户端。
struct ClientDTO: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var icon: String
}