import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// 类型化请求描述。Repository 负责构造具体 endpoint。
struct Endpoint: Sendable {
    var path: String
    var method: HTTPMethod
    var query: [URLQueryItem]
    var body: Data?
    var contentType: String

    init(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String = "application/json"
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.contentType = contentType
    }

    /// 以 JSON 编码一个 `Encodable` 作为请求体的 POST。
    static func post<Body: Encodable>(_ path: String, body: Body) throws -> Endpoint {
        Endpoint(path: path, method: .post, body: try JSONEncoder().encode(body))
    }

    /// 无请求体的 POST（多数 magpie 动作接口）。
    static func post(_ path: String) -> Endpoint {
        Endpoint(path: path, method: .post)
    }

    static func get(_ path: String, query: [URLQueryItem] = []) -> Endpoint {
        Endpoint(path: path, method: .get, query: query)
    }
}