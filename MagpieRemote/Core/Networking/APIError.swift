import Foundation

/// 网络层统一错误，映射为可读的本地化提示。
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case forbidden
    case http(status: Int, message: String)
    case decoding(String)
    case transport(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "服务器地址无效。")
        case .unauthorized:
            return String(localized: "鉴权失败：Web Key 不正确或已失效，请更新连接。")
        case .forbidden:
            return String(localized: "服务器拒绝了该请求（403）。")
        case .http(let status, let message):
            return message.isEmpty
                ? String(localized: "服务器返回错误（\(status)）。")
                : message
        case .decoding(let detail):
            return String(localized: "数据解析失败：\(detail)")
        case .transport(let detail):
            return String(localized: "网络请求失败：\(detail)")
        case .offline:
            return String(localized: "当前无网络连接。")
        }
    }

    /// 是否为鉴权类错误（用于触发重新登录）。
    var isAuth: Bool {
        switch self {
        case .unauthorized, .forbidden: return true
        default: return false
        }
    }

    /// 从原始解码错误构造具有可读路径信息的 APIError。
    static func from(decodingError error: Error) -> APIError {
        guard let decodingError = error as? DecodingError else {
            return .decoding(error.localizedDescription)
        }
        switch decodingError {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let key = path.isEmpty ? "<root>" : path
            return .decoding(String(localized: "字段 \(key) 类型不匹配（期望 \(String(describing: type))）：\(context.debugDescription)"))
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            let key = path.isEmpty ? "<root>" : path
            return .decoding(String(localized: "字段 \(key) 缺少值（期望 \(String(describing: type))）：\(context.debugDescription)"))
        case .keyNotFound(let key, let context):
            let path = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
            return .decoding(String(localized: "缺少必要字段 \(path)：\(context.debugDescription)"))
        case .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return .decoding(String(localized: "数据损坏 \(path.isEmpty ? "" : "(\(path)): ")\(context.debugDescription)"))
        @unknown default:
            return .decoding(error.localizedDescription)
        }
    }
}