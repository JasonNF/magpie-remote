import Foundation

/// 全局复用的日期 / 数字格式化器。
///
/// 创建 `DateFormatter` / `ISO8601DateFormatter` 很贵（要加载区域数据），
/// 列表每次刷新逐行新建会白白消耗 CPU 与电量。Foundation 的这些格式化器在
/// iOS 7+ 上读操作是线程安全的；这里只在初始化时配置、之后不再修改属性，
/// 因此可以用 `nonisolated(unsafe)` 跨隔离域共享。
enum SharedFormatters {
    nonisolated(unsafe) static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let isoBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// `HH:mm:ss`
    nonisolated(unsafe) static let timeOfDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// `MM-dd HH:mm`
    nonisolated(unsafe) static let monthDayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    /// 接口里的日期键 `yyyy-MM-dd`（POSIX，按本地时区）。
    nonisolated(unsafe) static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    /// 本地化短日期时间：同年省略年份（如「11/30 23:59」）。
    nonisolated(unsafe) static let localShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMdHHmm")
        return f
    }()

    nonisolated(unsafe) static let localShortWithYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yyyyMMdHHmm")
        return f
    }()

    /// 最多两位小数、带千分位。
    nonisolated(unsafe) static let decimal2: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    /// ISO 8601 解析，先试带毫秒的格式，再试不带毫秒的。
    static func parseISO(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return isoFractional.date(from: raw) ?? isoBasic.date(from: raw)
    }
}
