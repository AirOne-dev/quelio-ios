import Foundation
import SwiftUI

@MainActor
enum PreviewFixtures {
    private static let loginResponseJSON = """
    {
      "preferences": {
        "theme": "midnight",
        "minutes_objective": 2280
      },
      "token": "preview-token",
      "weeks": {
        "2026-w-08": {
          "days": {
            "16-02-2026": {
              "hours": [
                "08:30",
                "10:34",
                "10:42",
                "12:06",
                "13:06"
              ],
              "breaks": {
                "morning": "00:08",
                "noon": "01:00",
                "afternoon": "00:00"
              },
              "effective_to_paid": [
                "+ 00:07 => morning break"
              ],
              "effective": "04:11",
              "paid": "04:18"
            }
          },
          "total_effective": "04:11",
          "total_paid": "04:18"
        }
      }
    }
    """

    enum ExpansionMode {
        case today
        case firstFilled
        case collapsed
    }

    static var payload: KelioAPIResponse {
        normalizeWeek(from: decodedPayload)
    }

    static func makeLoggedInViewModel(
        offline: Bool = false,
        expansionMode: ExpansionMode = .today
    ) -> AppViewModel {
        let viewModel = AppViewModel(shouldAutoLogin: false)
        let payload = self.payload

        viewModel.phase = .loggedIn
        viewModel.username = "martin"
        viewModel.password = ""
        viewModel.loginError = nil
        viewModel.apiBaseURL = "http://localhost:8080/"
        viewModel.response = payload
        viewModel.theme = AppTheme.from(serverValue: payload.preferences?.theme) ?? .midnight
        viewModel.weeklyObjectiveMinutes = payload.preferences?.minutesObjective ?? 2_280
        viewModel.isOffline = offline
        viewModel.lastSyncDate = Date().addingTimeInterval(-120)
        viewModel.absences = [:]

        switch expansionMode {
        case .today:
            if let todayKey = viewModel.todayPresentation?.dateKey,
               let today = viewModel.todayPresentation,
               !today.timeBlocks.isEmpty {
                viewModel.expandedDays = [todayKey]
            } else {
                viewModel.expandedDays = []
            }
        case .firstFilled:
            if let firstFilled = viewModel.dayPresentations.first(where: { !$0.timeBlocks.isEmpty }) {
                viewModel.expandedDays = [firstFilled.dateKey]
            } else {
                viewModel.expandedDays = []
            }
        case .collapsed:
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
        viewModel.theme = .midnight
        viewModel.apiBaseURL = "http://localhost:8080/"
        return viewModel
    }

    static func makeLoadingViewModel() -> AppViewModel {
        let viewModel = AppViewModel(shouldAutoLogin: false)
        viewModel.phase = .loading
        viewModel.theme = .midnight
        return viewModel
    }

    static var sampleExpandedDay: DayPresentation {
        let viewModel = makeLoggedInViewModel(offline: false, expansionMode: .firstFilled)
        return viewModel.dayPresentations.first(where: { !$0.timeBlocks.isEmpty }) ?? fallbackDay
    }

    static var sampleFutureDay: DayPresentation {
        let viewModel = makeLoggedInViewModel(offline: false, expansionMode: .firstFilled)
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
                preferences: UserPreferences(theme: "midnight", minutesObjective: 2_280),
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
        let targetDates = Set(Date.weekDateKeys())

        var mappedDays: [String: DayPayload] = [:]
        for (dateKey, day) in sourceWeek.days where targetDates.contains(dateKey) {
            mappedDays[dateKey] = day
        }

        if mappedDays.isEmpty {
            return payload
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

#if DEBUG
enum ScreenshotScenario: String, CaseIterable {
    case loading
    case login
    case dashboard
    case dashboardClosed = "dashboard-closed"
    case settings

    static let launchFlag = "--screenshot"

    static func fromProcessArguments(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ScreenshotScenario? {
        guard let flagIndex = arguments.firstIndex(of: launchFlag) else {
            return nil
        }
        let valueIndex = flagIndex + 1
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return ScreenshotScenario(rawValue: arguments[valueIndex])
    }

    @MainActor
    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .loading:
            AppRootView(viewModel: PreviewFixtures.makeLoadingViewModel())
        case .login:
            AppRootView(viewModel: PreviewFixtures.makeLoggedOutViewModel())
        case .dashboard:
            AppRootView(viewModel: PreviewFixtures.makeLoggedInViewModel(
                offline: false,
                expansionMode: .today
            ))
        case .dashboardClosed:
            AppRootView(viewModel: PreviewFixtures.makeLoggedInViewModel(
                offline: false,
                expansionMode: .collapsed
            ))
        case .settings:
            let viewModel = PreviewFixtures.makeLoggedInViewModel(
                offline: false,
                expansionMode: .collapsed
            )
            PreviewHost(viewModel: viewModel) {
                NavigationStack {
                    SettingsView(viewModel: viewModel)
                }
            }
        }
    }
}
#endif

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
