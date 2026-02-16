import Foundation

enum AbsenceSection: String, Codable, CaseIterable {
    case none
    case day
    case morning
    case afternoon

    var label: String {
        switch self {
        case .none: return "Présent"
        case .day: return "Journée"
        case .morning: return "Matin"
        case .afternoon: return "Après-midi"
        }
    }
}

struct TimeBlock: Identifiable, Hashable {
    let id = UUID()
    let start: String
    let end: String
    let durationMinutes: Int
}

struct DayPresentation: Identifiable, Hashable {
    let id: String
    let dateKey: String
    let title: String
    let isPast: Bool
    let absence: AbsenceSection
    let timeBlocks: [TimeBlock]

    var totalMinutes: Int {
        timeBlocks.reduce(0) { $0 + max(0, $1.durationMinutes) }
    }

    var isFullyAbsent: Bool {
        absence == .day
    }

    var isPartiallyAbsent: Bool {
        absence == .morning || absence == .afternoon
    }
}

struct DayProgressSnapshot: Identifiable, Hashable {
    let id: String
    let label: String
    let minutes: Int
    let progress: Double
    let isToday: Bool
    let isWeekend: Bool
    let isAbsent: Bool
}

#if DEBUG
import SwiftUI

#Preview("DayPresentation") {
    let day = PreviewFixtures.sampleExpandedDay
    return VStack(alignment: .leading, spacing: 6) {
        Text(day.title).font(.headline)
        Text("Absence: \(day.absence.label)")
        Text("Blocs: \(day.timeBlocks.count)")
        Text("Total: \(TimeMath.minutesToHHMM(day.totalMinutes))")
    }
    .font(.caption)
    .padding()
}
#endif
