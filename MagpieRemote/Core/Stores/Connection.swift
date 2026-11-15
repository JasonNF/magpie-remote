import Foundation
import SwiftData

/// 一个 magpie 服务器连接的配置（机密 Web Key 存 Keychain，不在此处）。
@Model
final class Connection {
    @Attribute(.unique) var id: UUID
    var name: String
    var urlString: String
    var createdAt: Date
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, urlString: String, createdAt: Date = .now, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    var url: URL? { URL(string: urlString) }
}