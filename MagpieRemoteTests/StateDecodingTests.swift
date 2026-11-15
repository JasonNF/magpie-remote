import XCTest
@testable import MagpieRemote

/// StateDTO 解码与选项展开测试。
final class StateDecodingTests: XCTestCase {
    func testDecodeStateAndResolveOptions() throws {
        let json = """
        {
          "agents": [
            {
              "id": "claude", "name": "Claude Code", "icon": "claudecode-color",
              "path": "~/.claude/settings.json", "wired": true,
              "fields": [
                {"key": "model", "label": "model", "value": "anthropic/claude-opus-4-5", "options": null, "list": 1},
                {"key": "effort", "label": "effort", "value": "high",
                 "options": [{"value": "high", "label": "High"}, {"value": "low", "label": "Low"}]}
              ]
            }
          ],
          "profiles": [{"name": "work", "summary": "2 agents", "inUse": true}],
          "served": 3,
          "options": [
            {"value": "anthropic/claude-opus-4-5", "label": "Claude Opus 4.5"},
            {"value": "openai/gpt-5", "label": "GPT-5"}
          ],
          "optionLists": [[0, 1]]
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(StateDTO.self, from: json)
        XCTAssertEqual(state.agents.count, 1)
        XCTAssertEqual(state.agents[0].name, "Claude Code")
        XCTAssertEqual(state.profiles?.first?.name, "work")
        XCTAssertEqual(state.served, 3)

        // list=1 → optionLists[0] → 展开为两个选项
        let modelField = state.agents[0].fields[0]
        let resolved = state.options(for: modelField)
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].value, "anthropic/claude-opus-4-5")
        XCTAssertEqual(resolved[0].displayName, "Claude Opus 4.5")

        // 自带 options 的字段
        let effortField = state.agents[0].fields[1]
        XCTAssertEqual(state.options(for: effortField).count, 2)
    }

    func testDecodeStateWithSettingsTypes() throws {
        let json = """
        {
          "agents": [],
          "settings": {
            "theme": "dark",
            "lang": "zh-CN",
            "currency": "cny",
            "lan": true,
            "redact": true,
            "redactPersonal": true,
            "tray": "panel",
            "sessionTerminal": "ghostty",
            "updateEvery": 360,
            "claudeCache": [{"knob": "cache_ttl"}],
            "claudeAttribution": "off",
            "visionAuto": "codex/gpt-6-luna"
          }
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(StateDTO.self, from: json)
        XCTAssertEqual(state.settings?.theme, "dark")
        XCTAssertEqual(state.settings?.tray, "panel")
        XCTAssertEqual(state.settings?.updateEvery, 360)
        XCTAssertEqual(state.settings?.currency, "cny")
        XCTAssertEqual(state.settings?.claudeCacheEnabled, true)
        XCTAssertEqual(state.settings?.claudeAttributionOff, false)
        XCTAssertEqual(state.settings?.visionAutoModel, "codex/gpt-6-luna")
    }

    func testAPIErrorFromDecodingErrorFormatsClearDescription() {
        struct Sample: Decodable {
            var count: Int
        }
        let badJSON = "{\"count\": \"not-a-number\"}".data(using: .utf8)!
        do {
            _ = try JSONDecoder().decode(Sample.self, from: badJSON)
            XCTFail("Should fail")
        } catch {
            let apiError = APIError.from(decodingError: error)
            let desc = apiError.errorDescription ?? ""
            XCTAssertTrue(desc.contains("count"), "应包含出错字段 count，实际为: \(desc)")
            XCTAssertTrue(desc.contains("数据解析失败"), "应包含数据解析失败前缀")
        }
    }

    func testSetRequestUsesCapitalizedKeys() throws {
        let data = try JSONEncoder().encode(SetRequest(agent: "claude", field: "model", value: "x"))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(obj?["Agent"], "claude")
        XCTAssertEqual(obj?["Field"], "model")
        XCTAssertEqual(obj?["Value"], "x")
    }
}