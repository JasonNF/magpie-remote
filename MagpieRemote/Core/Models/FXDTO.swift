import Foundation

/// magpie `fxJSON`：美元→人民币汇率（货币选 cny 时用）。
struct FXDTO: Codable, Sendable, Hashable {
    var rate: Double?
    var stale: Bool?
}