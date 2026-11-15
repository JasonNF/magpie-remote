import XCTest
@testable import MagpieRemote

/// 对真实 magpie web 实例的集成验证。
/// 仅当设置 MAGPIE_TEST_URL / MAGPIE_TEST_KEY 环境变量时运行（凭据不进源码）。
final class LiveIntegrationTests: XCTestCase {
    func testFetchAndDecodeLiveState() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let urlString = env["MAGPIE_TEST_URL"], let key = env["MAGPIE_TEST_KEY"],
              let url = URL(string: urlString) else {
            throw XCTSkip("未设置 MAGPIE_TEST_URL / MAGPIE_TEST_KEY，跳过真实实例测试。")
        }
        let client = MagpieAPIClient(baseURL: url, key: key)
        try await client.signIn()
        let state = try await client.send(.get("/api/state"), as: StateDTO.self)
        XCTAssertFalse(state.agents.isEmpty, "应至少解析出一个 Agent")
        XCTAssertNotNil(state.options)
        // 展开第一个 Agent 的 model 字段选项，验证索引解析不越界。
        if let agent = state.agents.first, let field = agent.fields.first(where: { $0.key == "model" }) {
            let resolved = state.options(for: field)
            XCTAssertFalse(resolved.isEmpty, "model 字段应能展开出选项")
        }
    }
}