import Foundation

extension Date {
    private static let weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    private static let dataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    private static let frenchLongFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    static func currentISOWeekKey(now: Date = .now) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone.current

        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return "\(year)-w-\(String(format: "%02d", week))"
    }

    static func weekDateKeys(now: Date = .now) -> [String] {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone.current

        let startOfDay = calendar.startOfDay(for: now)
        guard let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)) else {
            return []
        }
        weekDateFormatter.calendar = calendar

        return (0..<7).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monday) else {
                return nil
            }
            return weekDateFormatter.string(from: day)
        }
    }

    static func parseDataDate(_ value: String) -> Date? {
        dataDateFormatter.date(from: value)
    }

    static func frenchLongTitle(for value: String) -> String {
        guard let date = parseDataDate(value) else {
            return value
        }

        let text = frenchLongFormatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    static func isPastDataDate(_ value: String) -> Bool {
        guard let date = parseDataDate(value) else {
            return false
        }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        return day < today
    }
}

#if DEBUG
import SwiftUI

#Preview("Date Utils") {
    VStack(alignment: .leading, spacing: 6) {
        Text("Semaine: \(Date.currentISOWeekKey())")
        Text("Jours: \(Date.weekDateKeys().joined(separator: ", "))")
    }
    .font(.caption2)
    .padding()
}
#endif
