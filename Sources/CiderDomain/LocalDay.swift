import Foundation

public struct LocalDay: Codable, Hashable, Comparable, Sendable, Identifiable {
    public let year: Int
    public let month: Int
    public let day: Int
    public var id: String { String(format: "%04d-%02d-%02d", year, month, day) }
    public init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }
    private enum CodingKeys: String, CodingKey { case year, month, day }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let y = try c.decode(Int.self, forKey: .year)
        let m = try c.decode(Int.self, forKey: .month)
        let d = try c.decode(Int.self, forKey: .day)
        let calendar = Calendar(identifier: .gregorian)
        guard (1...9999).contains(y), (1...12).contains(m), (1...31).contains(d),
              let date = calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)),
              calendar.component(.day, from: date) == d,
              calendar.component(.month, from: date) == m else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid planned day"))
        }
        year = y; month = m; day = d
    }
    public init(_ date: Date = .now, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        year = c.year!; month = c.month!; day = c.day!
    }
    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    public func adding(_ count: Int, calendar: Calendar = .current) -> LocalDay {
        LocalDay(calendar.date(byAdding: .day, value: count, to: date(calendar: calendar))!, calendar: calendar)
    }
    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool { lhs.id < rhs.id }
}
