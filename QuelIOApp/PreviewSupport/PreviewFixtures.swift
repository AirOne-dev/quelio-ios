import Foundation
import SwiftUI

@MainActor
enum PreviewFixtures {
    private static let loginResponseJSON = """
    {
      "preferences": {
        "theme": "forest",
        "minutes_objective": 2280
      },
      "token": "preview-token",
      "weeks": {
        "2026-w-07": {
          "days": {
            "09-02-2026": {
              "hours": [
                "08:31",
                "10:41",
                "10:49",
                "12:13",
                "13:19",
                "15:42",
                "15:48",
                "17:47"
              ],
              "effective": "07:56",
              "paid": "08:10"
            },
            "10-02-2026": {
              "hours": [
                "08:30",
                "12:02",
                "13:04",
                "15:40",
                "15:46",
                "17:31"
              ],
              "effective": "07:53",
              "paid": "08:07"
            },
            "11-02-2026": {
              "hours": [
                "08:32",
                "10:50",
                "10:56",
                "12:07",
                "13:02",
                "15:43",
                "15:51",
                "17:16"
              ],
              "effective": "07:35",
              "paid": "07:44"
            },
            "12-02-2026": {
              "hours": [
                "08:30",
                "10:41",
                "10:47"
              ],
              "effective": "02:30",
              "paid": "02:37"
            }
          },
          "total_effective": "25:54",
          "total_paid": "26:38"
        }
      }
    }
    """

    static var payload: KelioAPIResponse {
        normalizeWeek(from: decodedPayload)
    }

    static func makeLoggedInViewModel(offline: Bool = false, expandToday: Bool = true) -> AppViewModel {
        let viewModel = AppViewModel(shouldAutoLogin: false)
        let payload = self.payload

        viewModel.phase = .loggedIn
        viewModel.username = "martin"
        viewModel.password = ""
        viewModel.loginError = nil
        viewModel.apiBaseURL = "http://localhost:8080/"
        viewModel.response = payload
        viewModel.theme = AppTheme.from(serverValue: payload.preferences?.theme) ?? .forest
        viewModel.weeklyObjectiveMinutes = payload.preferences?.minutesObjective ?? 2_280
        viewModel.isOffline = offline
        viewModel.lastSyncDate = Date().addingTimeInterval(-120)

        var previewAbsences: [String: AbsenceSection] = [:]
        if let futureDay = viewModel.dayPresentations.first(where: { !$0.isPast }) {
            previewAbsences[futureDay.dateKey] = .morning
        }
        viewModel.absences = previewAbsences

        if expandToday, let todayKey = viewModel.todayPresentation?.dateKey {
            viewModel.expandedDays = [todayKey]
        } else if let firstFilled = viewModel.dayPresentations.first(where: { !$0.timeBlocks.isEmpty }) {
            viewModel.expandedDays = [firstFilled.dateKey]
        } else {
            viewModel.expandedDays = []
        }

        return viewModel
    }

    static func makeLoggedOutViewModel(error: String? = nil) -> AppViewModel {
        let viewModel = AppViewModel(shouldAutoLogin: false)
        viewModel.phase = .loggedOut
        viewModel.username = "martin"
        viewModel.password = "••••••••"
        viewModel.loginError = error
        viewModel.theme = .forest
        viewModel.apiBaseURL = "http://localhost:8080/"
        return viewModel
    }

    static func makeLoadingViewModel() -> AppViewModel {
        let viewModel = AppViewModel(shouldAutoLogin: false)
        viewModel.phase = .loading
        viewModel.theme = .forest
        return viewModel
    }

    static var sampleExpandedDay: DayPresentation {
        let viewModel = makeLoggedInViewModel(offline: false, expandToday: false)
        return viewModel.dayPresentations.first(where: { !$0.timeBlocks.isEmpty }) ?? fallbackDay
    }

    static var sampleFutureDay: DayPresentation {
        let viewModel = makeLoggedInViewModel(offline: false, expandToday: false)
        if let day = viewModel.dayPresentations.first(where: { $0.isPast == false }) {
            return day
        }
        return fallbackFutureDay
    }

    static var sampleTimelineBlocks: [TimeBlock] {
        let blocks = sampleExpandedDay.timeBlocks
        return blocks.isEmpty ? [
            TimeBlock(start: "08:30", end: "12:00", durationMinutes: 210),
            TimeBlock(start: "13:00", end: "17:30", durationMinutes: 270)
        ] : blocks
    }

    static var sampleWidgetSnapshot: WidgetSnapshot {
        let viewModel = makeLoggedInViewModel()
        let today = viewModel.todayPresentation
        let sortedTodayBlocks = (today?.timeBlocks ?? []).sorted {
            TimeMath.timeToMinutes($0.start) < TimeMath.timeToMinutes($1.start)
        }
        let todayWorkedMinutes = today?.totalMinutes ?? 0
        let dailyTargetMinutes = max(Int(round(Double(viewModel.weeklyObjectiveMinutes) / Double(viewModel.activeWeekdaysCount))), 0)
        let todayIsWorking = {
            guard let today else { return false }
            guard let hours = viewModel.response.weeks.values.first?.days[today.dateKey]?.hours else { return false }
            return !hours.count.isMultiple(of: 2)
        }()
        let todayRanges = sortedTodayBlocks.map { block in
            WidgetTimeRange(start: block.start, end: block.end)
        }

        return WidgetSnapshot(
            totalEffective: viewModel.totalEffective,
            totalPaid: viewModel.totalPaid,
            remaining: TimeMath.minutesToHHMM(max(viewModel.remainingMinutes, 0)),
            progress: viewModel.progressPercentage,
            isOffline: viewModel.isOffline,
            lastSync: Date().addingTimeInterval(-90),
            theme: viewModel.theme.rawValue,
            accentHex: viewModel.theme.accentHex,
            accentSecondaryHex: viewModel.theme.accentSecondaryHex,
            backgroundStartHex: viewModel.theme.backgroundStartHex,
            backgroundEndHex: viewModel.theme.backgroundEndHex,
            isLightTheme: viewModel.theme.isLightTheme,
            todayWorked: TimeMath.minutesToHHMM(todayWorkedMinutes),
            todayTarget: TimeMath.minutesToHHMM(dailyTargetMinutes),
            todayRemaining: TimeMath.minutesToHHMM(max(dailyTargetMinutes - todayWorkedMinutes, 0)),
            todaySessions: sortedTodayBlocks.count,
            todayFirstIn: sortedTodayBlocks.first?.start,
            todayLastOut: sortedTodayBlocks.last?.end,
            todayRanges: todayRanges,
            todayIsAbsent: today?.absence == .day,
            todayIsWorking: todayIsWorking
        )
    }

    private static var decodedPayload: KelioAPIResponse {
        guard let data = loginResponseJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(KelioAPIResponse.self, from: data) else {
            return KelioAPIResponse(
                preferences: UserPreferences(theme: "forest", minutesObjective: 2_280),
                token: "preview-token",
                weeks: [:],
                error: nil
            )
        }
        return payload
    }

    private static func normalizeWeek(from payload: KelioAPIResponse) -> KelioAPIResponse {
        guard let sourceWeek = payload.weeks.values.first else {
            return payload
        }

        let targetWeekKey = Date.currentISOWeekKey()
        let targetDates = Date.weekDateKeys()
        let sortedSourceDays = sourceWeek.days.sorted { lhs, rhs in
            let lhsDate = Date.parseDataDate(lhs.key) ?? .distantPast
            let rhsDate = Date.parseDataDate(rhs.key) ?? .distantPast
            return lhsDate < rhsDate
        }

        var mappedDays: [String: DayPayload] = [:]
        for (index, dateKey) in targetDates.enumerated() {
            if index < sortedSourceDays.count {
                mappedDays[dateKey] = sortedSourceDays[index].value
            } else {
                mappedDays[dateKey] = DayPayload(hours: [])
            }
        }

        return KelioAPIResponse(
            preferences: payload.preferences,
            token: payload.token,
            weeks: [targetWeekKey: WeekPayload(
                days: mappedDays,
                totalEffective: sourceWeek.totalEffective,
                totalPaid: sourceWeek.totalPaid
            )],
            error: nil
        )
    }

    private static var fallbackDay: DayPresentation {
        DayPresentation(
            id: "preview-day",
            dateKey: Date.weekDateKeys().first ?? "01-01-2026",
            title: "Lundi 1 janvier",
            isPast: true,
            absence: .none,
            timeBlocks: [
                TimeBlock(start: "08:30", end: "12:00", durationMinutes: 210),
                TimeBlock(start: "13:00", end: "17:30", durationMinutes: 270)
            ]
        )
    }

    private static var fallbackFutureDay: DayPresentation {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd-MM-yyyy"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let key = formatter.string(from: tomorrow)

        return DayPresentation(
            id: key,
            dateKey: key,
            title: Date.frenchLongTitle(for: key),
            isPast: false,
            absence: .none,
            timeBlocks: []
        )
    }
}

struct PreviewHost<Content: View>: View {
    let viewModel: AppViewModel
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            ThemedBackground(theme: viewModel.theme)
            content
        }
        .tint(viewModel.theme.accent)
        .preferredColorScheme(viewModel.theme.preferredColorScheme)
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}

#Preview("Fixtures") {
    let viewModel = PreviewFixtures.makeLoggedInViewModel()
    return VStack(alignment: .leading, spacing: 6) {
        Text("Utilisateur: \(viewModel.username)")
        Text("Theme: \(viewModel.theme.label)")
        Text("Total payé: \(viewModel.totalPaid)")
    }
    .font(.caption)
    .padding()
}
