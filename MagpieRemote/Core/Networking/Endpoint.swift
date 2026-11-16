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
        var cleanPath = path
        var combinedQuery = query

        // 自动解析 path 中可能包含的 query 字符串（如 /api/gateway/trace?after=0）
        if let questionIndex = path.firstIndex(of: "?") {
            cleanPath = String(path[..<questionIndex])
            let queryString = String(path[path.index(after: questionIndex)...])
            if let dummyURL = URL(string: "http://localhost?" + queryString),
               let comps = URLComponents(url: dummyURL, resolvingAgainstBaseURL: false),
               let parsedItems = comps.queryItems {
                combinedQuery.append(contentsOf: parsedItems)
            }
        }

        self.path = cleanPath
        self.method = method
        self.query = combinedQuery
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