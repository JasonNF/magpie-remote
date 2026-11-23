import XCTest
@testable import MagpieRemote

final class ModelDecodingTests: XCTestCase {
    func testDecodeProviders() throws {
        let json = """
        {
          "providers": [
            {
              "id": "deepseek",
              "name": "DeepSeek",
              "host": "api.deepseek.com",
              "off": false,
              "models": ["deepseek-chat", "deepseek-coder"],
              "keyList": [
                {"id": "k1", "masked": "sk-abc...xyz", "active": true, "on": true}
              ]
            }
          ],
          "presets": [
            {"id": "kimi", "name": "Kimi Code", "kind": "partner", "added": false}
          ]
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(ProvidersResponseDTO.self, from: json)
        XCTAssertEqual(res.providers.count, 1)
        XCTAssertEqual(res.providers[0].name, "DeepSeek")
        XCTAssertFalse(res.providers[0].isOff)
        XCTAssertEqual(res.providers[0].models?.count, 2)
        XCTAssertEqual(res.providers[0].models?[0].id, "deepseek-chat")
        XCTAssertEqual(res.providers[0].keyList?.count, 1)
        XCTAssertEqual(res.presets?.count, 1)
    }

    func testDecodeProvidersWithObjectModels() throws {
        let json = """
        {
          "providers": [
            {
              "id": "grok",
              "name": "xAI Grok",
              "models": [
                {"id": "grok-4", "name": "Grok 4 (Reasoning)", "on": true},
                {"id": "grok-code", "name": "grok-code", "on": false}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(ProvidersResponseDTO.self, from: json)
        XCTAssertEqual(res.providers.count, 1)
        let models = res.providers[0].models ?? []
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].id, "grok-4")
        XCTAssertEqual(models[0].name, "Grok 4 (Reasoning)")
        XCTAssertEqual(models[0].displayName, "Grok 4 (Reasoning) (grok-4)")
        XCTAssertEqual(models[1].displayName, "grok-code")
    }

    func testDecodeGroups() throws {
        let json = """
        {
          "groups": [
            {
              "id": "g1",
              "ref": "auto/deepseek-v4",
              "name": "DeepSeek V4",
              "routing": "smart",
              "ready": true,
              "members": ["provider1/modelA", "provider2/modelB"]
            }
          ],
          "found": true
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(GroupsResponseDTO.self, from: json)
        XCTAssertEqual(res.groups.count, 1)
        XCTAssertEqual(res.groups[0].name, "DeepSeek V4")
        XCTAssertTrue(res.groups[0].isAuto)
        XCTAssertEqual(res.groups[0].members?.count, 2)
    }

    func testDecodeUsageAndQuotas() throws {
        let json = """
        {
          "period": "30d",
          "calls": 12050,
          "input": 50000000,
          "output": 1000000,
          "cache_read": 20000000,
          "cost": 15.65
        }
        """.data(using: .utf8)!

        let usage = try JSONDecoder().decode(UsageDTO.self, from: json)
        XCTAssertEqual(usage.calls, 12050)
        XCTAssertEqual(usage.formattedCost, "$15.65")
        XCTAssertEqual(UsageDTO.formatTokens(usage.input ?? 0), "50.00 M")

        let quotaJson = """
        [
          {
            "provider": "codex",
            "name": "Codex",
            "balance": "$20.00",
            "windows": [
              {"name": "30 days", "used": 45.5, "remaining": 54.5}
            ]
          }
        ]
        """.data(using: .utf8)!

        let quotas = try JSONDecoder().decode([QuotaItemDTO].self, from: quotaJson)
        XCTAssertEqual(quotas.count, 1)
        XCTAssertEqual(quotas[0].windows?.first?.percentUsed, 45.5)
    }

    func testDecodeSessions() throws {
        let json = """
        {
          "sessions": [
            {
              "id": "sess-123",
              "agent": "claude",
              "name": "Claude Code",
              "title": "Fix login bug",
              "cost": 0.0521,
              "input": 15000,
              "output": 800,
              "last": "2026-11-14T06:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(SessionsResponseDTO.self, from: json)
        XCTAssertEqual(res.sessions.count, 1)
        XCTAssertEqual(res.sessions[0].displayTitle, "Fix login bug")
        XCTAssertEqual(res.sessions[0].displayAgent, "Claude Code")
    }

    func testDecodeGatewayKeys() throws {
        let json = """
        {
          "keys": [
            {
              "id": "key_abc",
              "name": "Work Laptop",
              "masked": "sk-magpie...99",
              "off": false,
              "admin": "local"
            }
          ]
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(GatewayKeysResponseDTO.self, from: json)
        XCTAssertEqual(res.keys.count, 1)
        XCTAssertEqual(res.keys[0].displayName, "Work Laptop")
        XCTAssertTrue(res.keys[0].isAdmin)
        XCTAssertFalse(res.keys[0].isOff)
    }

    func testDecodeGatewayKeyLimitUsage() throws {
        let json = """
        {
          "keys": [
            {
              "id": "key_abc",
              "name": "Work Laptop",
              "limit": {"period": "day", "tokens": 2000000},
              "moreLimits": [{"period": "week", "cost": 1.5}],
              "usedAll": [
                {
                  "period": "day",
                  "tokenLimit": 2000000,
                  "tokens": 1200000,
                  "tokensLeft": 800000,
                  "cost": 0.42,
                  "reset": "2026-11-16T00:00:00+08:00",
                  "spent": false
                },
                {
                  "period": "week",
                  "costLimit": 1.5,
                  "cost": 0.3,
                  "costLeft": 1.2,
                  "reset": "2026-11-17T00:00:00+08:00",
                  "spent": false
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let res = try JSONDecoder().decode(GatewayKeysResponseDTO.self, from: json)
        let key = try XCTUnwrap(res.keys.first)
        XCTAssertEqual(key.limits.count, 2)
        XCTAssertEqual(key.limitUsages.count, 2)
        XCTAssertEqual(key.limitUsages[0].tokensLeftDescription, "800.0 K / 2.00 M")
        XCTAssertEqual(key.limitUsages[1].costLeftDescription, "$1.20 / $1.50")
        XCTAssertFalse(key.limitUsages[0].isSpent)
        XCTAssertNotNil(key.limitUsages[0].resetDate)
    }

    func testQuotaItemsForDifferentAccountsHaveUniqueIDs() throws {
        let json = """
        [
          {"provider": "codex", "name": "Codex", "user": "alice", "windows": []},
          {"provider": "codex", "name": "Codex", "user": "bob", "windows": []},
          {"provider": "mistral", "name": "Mistral", "windows": []}
        ]
        """.data(using: .utf8)!

        let quotas = try JSONDecoder().decode([QuotaItemDTO].self, from: json)
        XCTAssertEqual(quotas.count, 3)
        XCTAssertEqual(quotas[0].user, "alice")
        XCTAssertEqual(Set(quotas.map(\.id)).count, quotas.count)
    }

    func testWorkBuddyCreditsDecodeAsAmountsAndPercent() throws {
        let json = """
        [
          {"provider": "workbuddy", "name": "WorkBuddy", "plan": "Free plan", "user": "fixture",
           "windows": [
             {"name": "Credits", "used": 0, "resetsAt": "2026-11-30T15:59:59Z", "display": "0 / 500", "limit": 500, "unit": "credits"},
             {"name": "Extra credits", "used": 0.09534333070244673, "display": "6.04 / 6335", "amount": 6.04, "limit": 6335,
              "unit": "credits", "runsOutAt": "2099-01-01T00:00:00Z", "runsOut": 99.96, "trayExtra": true},
             {"name": "Total credits", "used": 0.08836869056327724, "resetsAt": "2026-11-30T15:59:59Z", "display": "6.04 / 6835",
              "amount": 6.04, "limit": 6835, "unit": "credits", "holdsWhy": "low"},
             {"name": "deepseek-v4.1-flash tokens (est.)", "used": 0.042717, "display": "85k / ~200M", "amount": 85434, "limit": 200000000}
           ]},
          {"provider": "workbuddy", "name": "WorkBuddy", "user": "broken", "error": "sign in again", "windows": [{"name": 3}]},
          {"provider": "codex", "name": "Codex", "windows": [{"name": "Image generation", "used": 0, "display": "Unknown"}, {"name": "Weekly"}]}
        ]
        """.data(using: .utf8)!

        let quotas = try JSONDecoder().decode([QuotaItemDTO].self, from: json)
        XCTAssertEqual(quotas.count, 3)

        let wb = quotas[0]
        XCTAssertEqual(wb.plan, "Free plan")
        let extra = try XCTUnwrap(wb.windows?[1])
        // used 是百分比：0.095 表示 0.095%，不能放大成 9.5%
        XCTAssertEqual(extra.percentUsed, 0.09534333070244673, accuracy: 1e-9)
        XCTAssertEqual(extra.percentText, "<0.1%")
        XCTAssertTrue(extra.isCreditCount)
        XCTAssertEqual(extra.countText, "6.04 / 6,335")
        XCTAssertEqual(try XCTUnwrap(extra.leftAmount), 6328.96, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(extra.expiringSoon?.amount), 99.96, accuracy: 1e-9)
        XCTAssertEqual(extra.displayName, String(localized: "额外积分"))

        let summary = try XCTUnwrap(wb.creditSummaryWindow)
        XCTAssertEqual(summary.name, "Total credits")
        XCTAssertEqual(try XCTUnwrap(summary.leftAmount), 6828.96, accuracy: 1e-6)
        XCTAssertEqual(QuotaFormat.amount(6828.96), "6,828.96")

        let tokens = try XCTUnwrap(wb.windows?[3])
        XCTAssertFalse(tokens.isCreditCount)
        XCTAssertEqual(tokens.countText, "85k / ~200M")

        // 单个窗口字段异常只丢掉该窗口，账号和错误信息仍保留
        XCTAssertEqual(quotas[1].error, "sign in again")
        XCTAssertEqual(quotas[1].windows?.count, 0)
        XCTAssertTrue(quotas[1].hasNoData)

        // 缺省 used 表示未知，不是 0%；display "Unknown" 不当作计数展示
        let codex = quotas[2]
        XCTAssertNil(codex.windows?[0].countText)
        XCTAssertFalse(try XCTUnwrap(codex.windows?[1]).hasPercent)
        XCTAssertEqual(codex.windows?[1].percentText, "—")
        XCTAssertEqual(codex.windows?[0].percentUsed, 0)
        XCTAssertEqual(QuotaItemDTO.QuotaWindowDTO(name: "5 hours", used: 18).percentText, "18%")
    }

    func testSessionsWithSameIDUnderDifferentAgentsGetUniqueListIDs() throws {
        let json = """
        {"sessions": [
          {"id": "01a1ff1a-c01f-7060-a3ef-40820ab6cb4d", "agent": "omp", "title": "DEVIN"},
          {"id": "01a1ff1a-c01f-7060-a3ef-40820ab6cb4d", "agent": "claude"},
          {"id": "mwccyny367b5kygpi3e", "agent": "alma"}
        ]}
        """.data(using: .utf8)!
        let sessions = try JSONDecoder().decode(SessionsResponseDTO.self, from: json).sessions
        XCTAssertEqual(Set(sessions.map(\.id)).count, 2)
        XCTAssertEqual(Set(sessions.map(\.listID)).count, 3)
        XCTAssertEqual(sessions[1].id, "01a1ff1a-c01f-7060-a3ef-40820ab6cb4d")
    }

    func testSessionTimesFromDifferentAgentsShareOneTimeZone() throws {
        let utc = SessionDTO(id: "a", agent: "omp", last: "2026-11-22T17:33:42.171Z")
        let offset = SessionDTO(id: "b", agent: "claude", last: "2026-11-23T01:33:42.072347+08:00")
        let shortFraction = SessionDTO(id: "c", agent: "omp", last: "2026-11-22T17:33:42.11Z")
        // 同一时刻，不同写法，显示必须一致
        XCTAssertNotNil(utc.lastLocalText)
        XCTAssertEqual(utc.lastLocalText, offset.lastLocalText)
        XCTAssertEqual(utc.lastLocalText, shortFraction.lastLocalText)
        XCTAssertEqual(utc.lastLocalText?.count, 16)
        XCTAssertEqual(utc.lastLocalDay?.count, 10)
        // 解析不了时退回原始字符串前 16 位
        XCTAssertEqual(SessionDTO(id: "d", agent: "x", last: "weird-time-value-here").lastLocalText, "weird-time-value")
        XCTAssertNil(SessionDTO(id: "e", agent: "x").lastLocalText)
    }

    func testCancellationIsNotShownAsAnError() {
        XCTAssertNil(APIError.message(for: APIError.cancelled))
        XCTAssertNil(APIError.message(for: URLError(.cancelled)))
        XCTAssertNil(APIError.message(for: CancellationError()))
        XCTAssertNotNil(APIError.message(for: APIError.offline))
        XCTAssertNotNil(APIError.message(for: URLError(.timedOut)))
    }

    func testExtractCleanURLAndKey() {
        let input = "https://magpie.example.invalid/?k=fixture-web-key"
        let (clean, key) = ConnectionEditViewModel.extractCleanURLAndKey(from: input)
        XCTAssertEqual(clean, "https://magpie.example.invalid/")
        XCTAssertEqual(key, "fixture-web-key")

        let cleanOnly = "http://192.168.1.50:3426"
        let (resURL, resKey) = ConnectionEditViewModel.extractCleanURLAndKey(from: cleanOnly)
        XCTAssertEqual(resURL, "http://192.168.1.50:3426")
        XCTAssertNil(resKey)
    }

    func testRoutingFollowsAttemptedModelAcrossFallback() throws {
        func route(tries: String, done: Bool = false) throws -> GatewayRouteDTO {
            let json = """
            {
              "id": 30, "done": \(done), "ms": 420, "contentAt": 1000,
              "order": [
                { "id": "shared-account", "model": "primary" },
                { "id": "shared-account", "model": "backup", "fallback": true }
              ],
              "tries": [\(tries)]
            }
            """
            return try JSONDecoder().decode(GatewayRouteDTO.self, from: Data(json.utf8))
        }

        let waiting = try route(tries: "")
        XCTAssertNil(waiting.focusedAccountIndex)
        XCTAssertFalse(waiting.isRerouted)

        let primary = #"{"id":"shared-account","model":"primary","done":false}"#
        XCTAssertEqual(try route(tries: primary).focusedAccountIndex, 0)

        let failed = #"{"id":"shared-account","model":"primary","done":true,"status":429,"fail":"quota"}"#
        let backup = #"{"id":"shared-account","model":"backup","done":false}"#
        XCTAssertNil(try route(tries: failed).focusedAccountIndex)
        let fallback = try route(tries: failed + "," + backup)
        XCTAssertEqual(fallback.focusedAccountIndex, 1)
        XCTAssertTrue(fallback.isRerouted)

        let served = #"{"id":"shared-account","model":"backup","done":true,"status":200}"#
        let completed = try route(tries: failed + "," + served, done: true)
        XCTAssertEqual(completed.focusedAttempt?.model, "backup")
        XCTAssertTrue(completed.isSuccess)
        XCTAssertEqual(completed.millis, 420)
    }
}
