import Foundation

enum TimeMath {
    static let startOfDayMinutes = 8 * 60
    static let endOfDayMinutes = 19 * 60
    static let hardLowerBound = 8 * 60 + 30
    static let hardUpperBound = 18 * 60 + 30
    private static let hhmmFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func timeToMinutes(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return (parts[0] * 60) + parts[1]
    }

    static func minutesToHHMM(_ minutes: Int) -> String {
        let clamped = max(0, minutes)
        let hours = clamped / 60
        let remaining = clamped % 60
        return String(format: "%02d:%02d", hours, remaining)
    }

    static func minutesToSignedHHMM(_ minutes: Int) -> String {
        let sign = minutes < 0 ? "-" : ""
        let value = abs(minutes)
        return "\(sign)\(minutesToHHMM(value))"
    }

    static func minutesToHourLabel(_ minutes: Int) -> String {
        let value = max(0, minutes)
        return "\(value / 60)h\(String(format: "%02d", value % 60))"
    }

    static func durationMinutes(start: String, end: String) -> Int {
        max(0, timeToMinutes(end) - timeToMinutes(start))
    }

    static func blocks(from hours: [String], now: Date = .now) -> [TimeBlock] {
        let nowString = hhmmFormatter.string(from: now)

        var blocks: [TimeBlock] = []
        for index in stride(from: 0, to: hours.count, by: 2) {
            guard index < hours.count else { continue }
            let start = hours[index]
            let end = index + 1 < hours.count ? hours[index + 1] : nowString
            blocks.append(
                TimeBlock(
                    start: start,
                    end: end,
                    durationMinutes: durationMinutes(start: start, end: end)
                )
            )
        }
        return blocks
    }

    static func totalMinutes(from hours: [String], now: Date = .now) -> Int {
        let nowString = hhmmFormatter.string(from: now)

        var total = 0
        for index in stride(from: 0, to: hours.count, by: 2) {
            guard index < hours.count else { continue }
            let start = timeToMinutes(hours[index])
            let rawEnd = index + 1 < hours.count ? hours[index + 1] : nowString
            let end = timeToMinutes(rawEnd)

            let boundedStart = max(hardLowerBound, min(start, hardUpperBound))
            let boundedEnd = max(hardLowerBound, min(end, hardUpperBound))
            total += max(0, boundedEnd - boundedStart)
        }

        return total
    }

    static func timelineOffset(_ time: String) -> Double {
        let totalSpan = Double(endOfDayMinutes - startOfDayMinutes)
        let minutes = Double(timeToMinutes(time) - startOfDayMinutes)
        return min(max(minutes / totalSpan, 0), 1)
    }
}

#if DEBUG
import SwiftUI

#Preview("TimeMath") {
    VStack(alignment: .leading, spacing: 6) {
        Text("08:30 -> \(TimeMath.timeToMinutes("08:30")) min")
        Text("500 min -> \(TimeMath.minutesToHHMM(500))")
        Text("Offset 10:00 -> \(String(format: "%.2f", TimeMath.timelineOffset("10:00")))")
    }
    .font(.caption)
    .padding()
}
#endif
