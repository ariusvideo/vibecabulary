import Foundation

/// Day-keyed study helpers. Dates are passed in so they can be checked without a clock.
public enum StudyStats {
    /// "yyyy-MM-dd" in the user's time zone, so the day rolls over at local midnight.
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// A stable index for the given day: the same all day, different from day to day.
    /// Uses FNV-1a because Swift's `hashValue` changes between launches.
    public static func dailyIndex(dayKey: String, count: Int) -> Int? {
        guard count > 0 else { return nil }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in dayKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return Int(hash % UInt64(count))
    }
}

/// Distinct terms opened on one day. Reopening a term doesn't count twice.
public struct LookupLog: Codable, Equatable, Sendable {
    public var day: String
    public var terms: [String]

    public init(day: String = "", terms: [String] = []) {
        self.day = day
        self.terms = terms
    }

    /// The number of distinct terms opened on `day` (0 if the log is from an earlier day).
    public func count(on day: String) -> Int { self.day == day ? terms.count : 0 }

    /// Records `term` for `day`, starting over when the day has changed.
    public mutating func record(_ term: String, on day: String) {
        if self.day != day {
            self.day = day
            terms = []
        }
        if !terms.contains(term) { terms.append(term) }
    }
}
