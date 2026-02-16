import Foundation

struct WidgetTimeRange: Codable, Equatable {
    let start: String
    let end: String
}

struct WidgetSnapshot: Codable, Equatable {
    let totalEffective: String
    let totalPaid: String
    let remaining: String
    let progress: Int
    let isOffline: Bool
    let lastSync: Date
    let theme: String?
    let accentHex: String?
    let accentSecondaryHex: String?
    let backgroundStartHex: String?
    let backgroundEndHex: String?
    let isLightTheme: Bool?
    let todayWorked: String?
    let todayTarget: String?
    let todayRemaining: String?
    let todaySessions: Int?
    let todayFirstIn: String?
    let todayLastOut: String?
    let todayRanges: [WidgetTimeRange]?
    let todayIsAbsent: Bool?
    let todayIsWorking: Bool?

    static let placeholder = WidgetSnapshot(
        totalEffective: "00:00",
        totalPaid: "00:00",
        remaining: "38:00",
        progress: 0,
        isOffline: false,
        lastSync: .now,
        theme: "ocean",
        accentHex: "0EA5E9",
        accentSecondaryHex: "38BDF8",
        backgroundStartHex: "1E293B",
        backgroundEndHex: "0F172A",
        isLightTheme: false,
        todayWorked: "00:00",
        todayTarget: "07:36",
        todayRemaining: "07:36",
        todaySessions: 0,
        todayFirstIn: nil,
        todayLastOut: nil,
        todayRanges: [],
        todayIsAbsent: false,
        todayIsWorking: false
    )

    static let previewForest = WidgetSnapshot(
        totalEffective: "25:54",
        totalPaid: "26:38",
        remaining: "11:22",
        progress: 70,
        isOffline: false,
        lastSync: .now,
        theme: "forest",
        accentHex: "10B981",
        accentSecondaryHex: "34D399",
        backgroundStartHex: "1A1F1A",
        backgroundEndHex: "111411",
        isLightTheme: false,
        todayWorked: "02:30",
        todayTarget: "07:36",
        todayRemaining: "05:06",
        todaySessions: 2,
        todayFirstIn: "08:30",
        todayLastOut: "10:47",
        todayRanges: [
            WidgetTimeRange(start: "08:30", end: "09:22"),
            WidgetTimeRange(start: "09:38", end: "10:47")
        ],
        todayIsAbsent: false,
        todayIsWorking: true
    )

    static let previewDayNotStarted = WidgetSnapshot(
        totalEffective: "18:12",
        totalPaid: "18:40",
        remaining: "19:20",
        progress: 49,
        isOffline: false,
        lastSync: .now,
        theme: "forest",
        accentHex: "10B981",
        accentSecondaryHex: "34D399",
        backgroundStartHex: "1A1F1A",
        backgroundEndHex: "111411",
        isLightTheme: false,
        todayWorked: "00:00",
        todayTarget: "07:36",
        todayRemaining: "07:36",
        todaySessions: 0,
        todayFirstIn: nil,
        todayLastOut: nil,
        todayRanges: [],
        todayIsAbsent: false,
        todayIsWorking: false
    )
}

enum WidgetSharedStore {
    static let appGroupID = "group.io.quel.native"
    static let snapshotKey = "quelio_widget_snapshot_v1"

    static func loadSnapshot() -> WidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: snapshotKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = try? JSONEncoder().encode(snapshot)
        else {
            return
        }

        defaults.set(data, forKey: snapshotKey)
    }

    static func clearSnapshot() {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.removeObject(forKey: snapshotKey)
    }
}

#if DEBUG
import SwiftUI

#Preview("Widget Snapshot") {
    VStack(alignment: .leading, spacing: 6) {
        Text("Payé: \(WidgetSnapshot.previewForest.totalPaid)")
        Text("Progression: \(WidgetSnapshot.previewForest.progress)%")
        Text("Aujourd'hui: \(WidgetSnapshot.previewForest.todayWorked ?? "--:--")")
    }
    .font(.caption)
    .padding()
}
#endif
