import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class AppViewModel: ObservableObject {
    enum Phase {
        case loading
        case loggedOut
        case loggedIn
    }

    @Published var phase: Phase = .loading
    @Published var username: String
    @Published var password = ""
    @Published var loginError: String?
    @Published var isBusy = false
    @Published var isOffline = false

    @Published var apiBaseURL: String
    @Published var theme: AppTheme
    @Published var weeklyObjectiveMinutes: Int

    @Published var response = KelioAPIResponse()
    @Published var absences: [String: AbsenceSection] = [:]
    @Published var expandedDays: Set<String> = []
    @Published var lastSyncDate: Date?
    @Published private var nowReference: Date = .now

    private static let lastSyncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter
    }()

    private static let bestDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    private let store: SessionStore
    private let apiClient: KelioAPIClient
    private var clockTask: Task<Void, Never>?
    private var lastPublishedWidgetSnapshot: WidgetSnapshot?

    init(
        store: SessionStore = SessionStore(),
        apiClient: KelioAPIClient = KelioAPIClient(),
        shouldAutoLogin: Bool = true
    ) {
        self.store = store
        self.apiClient = apiClient

        let savedUsername = store.loadUsername() ?? ""
        username = savedUsername
        apiBaseURL = store.loadAPIBaseURL()

        if savedUsername.isEmpty {
            theme = .ocean
            weeklyObjectiveMinutes = 2_280
        } else {
            theme = store.loadTheme(for: savedUsername)
            weeklyObjectiveMinutes = store.loadObjective(for: savedUsername)
            absences = store.loadAbsences(for: savedUsername)
        }

        startClock()
        if shouldAutoLogin {
            Task { await autoLogin() }
        } else {
            phase = .loggedOut
        }
    }

    deinit {
        clockTask?.cancel()
    }

    var loginDisabled: Bool {
        username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || isBusy
    }

    var totalEffective: String {
        currentWeek?.totalEffective ?? "00:00"
    }

    var totalPaid: String {
        currentWeek?.totalPaid ?? "00:00"
    }

    var absenceCreditMinutes: Int {
        let equivalentDays = dayPresentations.reduce(0.0) { partial, day in
            switch day.absence {
            case .none:
                return partial
            case .day:
                return partial + 1.0
            case .morning, .afternoon:
                return partial + 0.5
            }
        }

        let creditedMinutes = Double(weeklyObjectiveMinutes) * (equivalentDays / 5.0)
        return Int(creditedMinutes.rounded())
    }

    var adjustedWeeklyObjectiveMinutes: Int {
        max(0, weeklyObjectiveMinutes - absenceCreditMinutes)
    }

    var remainingMinutes: Int {
        adjustedWeeklyObjectiveMinutes - TimeMath.timeToMinutes(totalPaid)
    }

    var progressPercentage: Int {
        let denominator = max(adjustedWeeklyObjectiveMinutes, 1)
        let ratio = Double(TimeMath.timeToMinutes(totalPaid)) / Double(denominator)
        return max(0, min(100, Int((ratio * 100).rounded())))
    }

    var lastSyncLabel: String {
        guard let lastSyncDate else { return "Jamais synchronisé" }
        let elapsed = max(0, Int(nowReference.timeIntervalSince(lastSyncDate)))

        if elapsed < 60 {
            return "Mis à jour à l'instant"
        }

        if elapsed < 3_600 {
            let minutes = elapsed / 60
            return "Mis à jour il y a \(minutes) min"
        }

        if elapsed < 86_400 {
            let hours = elapsed / 3_600
            return "Mis à jour il y a \(hours) h"
        }

        return "Mis à jour \(Self.lastSyncDateFormatter.string(from: lastSyncDate))"
    }

    var workedDays: Int {
        dayPresentations.filter { !$0.isFullyAbsent && !$0.timeBlocks.isEmpty }.count
    }

    var dailyAverageMinutes: Int {
        let pastDays = dayPresentations.filter { day in
            day.isPast && !day.isFullyAbsent && !day.timeBlocks.isEmpty
        }

        if pastDays.isEmpty {
            return TimeMath.timeToMinutes(totalEffective)
        }

        let total = pastDays.reduce(0) { $0 + $1.totalMinutes }
        return Int((Double(total) / Double(pastDays.count)).rounded())
    }

    var bestDay: DayPresentation? {
        let candidates = dayPresentations.filter { !$0.isFullyAbsent && !$0.timeBlocks.isEmpty }
        return candidates.max { $0.totalMinutes < $1.totalMinutes }
    }

    var bestDayShortName: String {
        guard let bestDay else { return "-" }
        guard let date = Date.parseDataDate(bestDay.dateKey) else { return "-" }

        let name = Self.bestDayFormatter.string(from: date)
        return name.prefix(1).uppercased() + name.dropFirst().lowercased()
    }

    var totalPaidMinutes: Int {
        TimeMath.timeToMinutes(totalPaid)
    }

    var totalEffectiveMinutes: Int {
        TimeMath.timeToMinutes(totalEffective)
    }

    var objectiveCompletion: Double {
        guard adjustedWeeklyObjectiveMinutes > 0 else { return 0 }
        return Double(totalPaidMinutes) / Double(adjustedWeeklyObjectiveMinutes)
    }

    var objectiveDeltaMinutes: Int {
        totalPaidMinutes - adjustedWeeklyObjectiveMinutes
    }

    var activeWeekdaysCount: Int {
        let count = dayPresentations.filter { day in
            !isWeekend(day.dateKey) && day.absence != .day
        }.count
        return max(count, 1)
    }

    var remainingWeekdaysCount: Int {
        dayPresentations.filter { day in
            !day.isPast && !isWeekend(day.dateKey) && day.absence != .day
        }.count
    }

    var neededDailyMinutes: Int? {
        guard remainingMinutes > 0, remainingWeekdaysCount > 0 else { return nil }
        return Int(ceil(Double(remainingMinutes) / Double(remainingWeekdaysCount)))
    }

    var averageSessionMinutes: Int {
        let allBlocks = dayPresentations.flatMap(\.timeBlocks)
        guard !allBlocks.isEmpty else { return 0 }
        let total = allBlocks.reduce(0) { $0 + $1.durationMinutes }
        return Int((Double(total) / Double(allBlocks.count)).rounded())
    }

    var weekPauseMinutes: Int {
        dayPresentations.reduce(into: 0) { total, day in
            total += pauseMinutes(for: day)
        }
    }

    var weekStatusLine: String {
        if objectiveDeltaMinutes >= 0 {
            return "Objectif dépassé de \(TimeMath.minutesToHHMM(objectiveDeltaMinutes))"
        }
        if let neededDailyMinutes {
            return "Il reste \(TimeMath.minutesToHHMM(remainingMinutes)) • \(TimeMath.minutesToHourLabel(neededDailyMinutes))/jour"
        }
        return "Il reste \(TimeMath.minutesToHHMM(remainingMinutes))"
    }

    var weekStatusIcon: String {
        if objectiveDeltaMinutes >= 0 { return "checkmark.seal.fill" }
        if progressPercentage >= 75 { return "chart.line.uptrend.xyaxis.circle.fill" }
        return "clock.badge.exclamationmark.fill"
    }

    var weekdayProgressSnapshots: [DayProgressSnapshot] {
        let expectedDaily = max(Int(round(Double(adjustedWeeklyObjectiveMinutes) / Double(activeWeekdaysCount))), 1)

        return dayPresentations.map { day in
            let minutes = day.totalMinutes
            return DayProgressSnapshot(
                id: day.dateKey,
                label: shortWeekdayLabel(day.dateKey),
                minutes: minutes,
                progress: Double(minutes) / Double(expectedDaily),
                isToday: !day.isPast && isSameDayAsToday(day.dateKey),
                isWeekend: isWeekend(day.dateKey),
                isAbsent: day.absence == .day
            )
        }
    }

    var dayPresentations: [DayPresentation] {
        let weekDays = Date.weekDateKeys()
        let payloadDays = currentWeek?.days ?? [:]

        return weekDays.map { dateKey in
            let payload = payloadDays[dateKey] ?? DayPayload(hours: [])
            let section = absences[dateKey] ?? .none

            return DayPresentation(
                id: dateKey,
                dateKey: dateKey,
                title: Date.frenchLongTitle(for: dateKey),
                isPast: Date.isPastDataDate(dateKey),
                absence: section,
                timeBlocks: TimeMath.blocks(from: payload.hours)
            )
        }
    }

    var todayPresentation: DayPresentation? {
        dayPresentations.first(where: { isSameDayAsToday($0.dateKey) })
    }

    var todayWorkedMinutes: Int {
        todayPresentation?.totalMinutes ?? 0
    }

    var pendingDaysCount: Int {
        dayPresentations.filter { day in
            !day.isPast && !isWeekend(day.dateKey) && day.absence == .none
        }.count
    }

    func autoLogin() async {
        guard !username.isEmpty else {
            phase = .loggedOut
            return
        }

        guard let token = store.loadToken(for: username) else {
            phase = .loggedOut
            return
        }

        await authenticate(username: username, password: nil, token: token, isAutoLogin: true)
    }

    func login() async {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty else {
            loginError = "Saisis ton identifiant."
            return
        }

        guard !password.isEmpty else {
            loginError = "Saisis ton mot de passe."
            return
        }

        await authenticate(
            username: cleanUsername,
            password: password,
            token: nil,
            isAutoLogin: false
        )
    }

    func refresh() async {
        guard phase == .loggedIn else { return }
        guard !isBusy else { return }
        guard let token = store.loadToken(for: username) else {
            phase = .loggedOut
            return
        }

        await refreshAuthenticatedSession(username: username, token: token)
    }

    func logout() {
        if !username.isEmpty {
            store.removeToken(for: username)
        }

        password = ""
        response = KelioAPIResponse()
        absences = [:]
        expandedDays = []
        isOffline = false
        loginError = nil
        phase = .loggedOut

        clearWidgetSnapshot()
    }

    func updateTheme(_ newTheme: AppTheme) {
        theme = newTheme
        guard !username.isEmpty else { return }

        store.saveTheme(newTheme, for: username)
        publishWidgetSnapshot()

        Task {
            await syncPreferences()
        }
    }

    func updateWeeklyObjectiveHours(_ hours: Int) {
        let clamped = min(max(hours, 1), 60)
        weeklyObjectiveMinutes = clamped * 60
        guard !username.isEmpty else { return }

        store.saveObjective(weeklyObjectiveMinutes, for: username)
        publishWidgetSnapshot()

        Task {
            await syncPreferences()
        }
    }

    func updateAPIBaseURL(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty
            ? "http://localhost:8080/"
            : (trimmed.hasSuffix("/") ? trimmed : "\(trimmed)/")

        apiBaseURL = normalized
        store.saveAPIBaseURL(normalized)
    }

    func isExpanded(_ dateKey: String) -> Bool {
        expandedDays.contains(dateKey)
    }

    func toggleExpanded(_ dateKey: String) {
        if expandedDays.contains(dateKey) {
            expandedDays.remove(dateKey)
        } else {
            expandedDays.insert(dateKey)
        }
    }

    func setAbsence(_ section: AbsenceSection, for dateKey: String) {
        if section == .none {
            absences.removeValue(forKey: dateKey)
        } else {
            absences[dateKey] = section
        }

        guard !username.isEmpty else { return }
        store.saveAbsences(absences, for: username)
        publishWidgetSnapshot()
    }

    func pauseMinutes(for day: DayPresentation) -> Int {
        guard day.timeBlocks.count >= 2 else { return 0 }

        let sorted = day.timeBlocks.sorted { lhs, rhs in
            TimeMath.timeToMinutes(lhs.start) < TimeMath.timeToMinutes(rhs.start)
        }

        var total = 0
        for index in 0..<(sorted.count - 1) {
            let previousEnd = TimeMath.timeToMinutes(sorted[index].end)
            let nextStart = TimeMath.timeToMinutes(sorted[index + 1].start)
            total += max(0, nextStart - previousEnd)
        }

        return total
    }

    func amplitudeMinutes(for day: DayPresentation) -> Int {
        let startMinutes = day.timeBlocks.map { TimeMath.timeToMinutes($0.start) }.min()
        let endMinutes = day.timeBlocks.map { TimeMath.timeToMinutes($0.end) }.max()
        guard let startMinutes, let endMinutes else {
            return 0
        }

        return max(0, endMinutes - startMinutes)
    }

    private var currentWeek: WeekPayload? {
        let currentKey = Date.currentISOWeekKey()

        if let value = response.weeks[currentKey] {
            return value
        }

        let latest = response.weeks.keys.sorted(by: >).first
        if let latest {
            return response.weeks[latest]
        }

        return nil
    }

    private func authenticate(
        username: String,
        password: String?,
        token: String?,
        isAutoLogin: Bool
    ) async {
        isBusy = true
        if !isAutoLogin {
            loginError = nil
        }

        defer {
            isBusy = false
        }

        do {
            let payload = try await apiClient.login(
                baseURL: apiBaseURL,
                username: username,
                password: password,
                token: token
            )
            applyAuthenticatedPayload(payload, username: username)
            phase = .loggedIn
        } catch let error as APIClientError {
            handleAuthError(error, isAutoLogin: isAutoLogin)
        } catch {
            if !isAutoLogin {
                loginError = "Erreur de connexion."
            }
            phase = .loggedOut
        }
    }

    private func applyAuthenticatedPayload(_ payload: KelioAPIResponse, username: String) {
        self.username = username
        store.saveUsername(username)

        if let token = payload.token, !token.isEmpty {
            store.saveToken(token, for: username)
        }

        response = payload
        password = ""
        isOffline = payload.error?.localizedCaseInsensitiveContains("cached data") == true
        lastSyncDate = .now

        if let themeFromServer = AppTheme.from(serverValue: payload.preferences?.theme) {
            theme = themeFromServer
        } else {
            theme = store.loadTheme(for: username)
        }

        if let minutesFromServer = payload.preferences?.minutesObjective, minutesFromServer > 0 {
            weeklyObjectiveMinutes = minutesFromServer
        } else {
            weeklyObjectiveMinutes = store.loadObjective(for: username)
        }

        store.saveTheme(theme, for: username)
        store.saveObjective(weeklyObjectiveMinutes, for: username)
        absences = store.loadAbsences(for: username)
        publishWidgetSnapshot()
    }

    private func handleAuthError(_ error: APIClientError, isAutoLogin: Bool) {
        switch error {
        case .tokenInvalidated:
            store.removeToken(for: username)
            loginError = "Session invalidée. Reconnecte-toi."
            clearWidgetSnapshot()
        case .tokenExpired:
            store.removeToken(for: username)
            loginError = isAutoLogin ? nil : "Session expirée. Reconnecte-toi."
            clearWidgetSnapshot()
        case .cancelled:
            if phase == .loading {
                phase = .loggedOut
            }
            return
        case let .badResponse(message):
            loginError = isAutoLogin ? nil : message
        default:
            loginError = isAutoLogin ? nil : (error.errorDescription ?? "Erreur de connexion")
        }

        phase = .loggedOut
    }

    private func refreshAuthenticatedSession(username: String, token: String) async {
        isBusy = true
        defer {
            isBusy = false
        }

        do {
            let payload = try await apiClient.login(
                baseURL: apiBaseURL,
                username: username,
                password: nil,
                token: token
            )
            applyAuthenticatedPayload(payload, username: username)
            phase = .loggedIn
        } catch let error as APIClientError {
            handleRefreshError(error)
        } catch {
            isOffline = true
            publishWidgetSnapshot()
        }
    }

    private func handleRefreshError(_ error: APIClientError) {
        switch error {
        case .cancelled:
            return
        case .tokenInvalidated:
            store.removeToken(for: username)
            loginError = "Session invalidée. Reconnecte-toi."
            phase = .loggedOut
            clearWidgetSnapshot()
        case .tokenExpired:
            store.removeToken(for: username)
            loginError = "Session expirée. Reconnecte-toi."
            phase = .loggedOut
            clearWidgetSnapshot()
        default:
            isOffline = true
            publishWidgetSnapshot()
        }
    }

    func syncWidgetsFromCurrentState() {
        publishWidgetSnapshot()
    }

    private func syncPreferences() async {
        guard phase == .loggedIn else { return }
        guard let token = store.loadToken(for: username) else { return }

        do {
            let payload = try await apiClient.updatePreferences(
                baseURL: apiBaseURL,
                token: token,
                theme: theme,
                minutesObjective: weeklyObjectiveMinutes
            )
            response = payload
        } catch {
            // Keep local values even if API sync fails.
        }
    }

    private func isWeekend(_ dateKey: String) -> Bool {
        guard let date = Date.parseDataDate(dateKey) else { return false }
        return Calendar.current.isDateInWeekend(date)
    }

    private func isSameDayAsToday(_ dateKey: String) -> Bool {
        guard let date = Date.parseDataDate(dateKey) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func shortWeekdayLabel(_ dateKey: String) -> String {
        guard let date = Date.parseDataDate(dateKey) else { return "-" }
        return Self.shortWeekdayFormatter.string(from: date).uppercased()
    }

    private func publishWidgetSnapshot() {
        guard phase == .loggedIn else { return }

        let today = todayPresentation
        let sortedTodayBlocks = (today?.timeBlocks ?? []).sorted {
            TimeMath.timeToMinutes($0.start) < TimeMath.timeToMinutes($1.start)
        }
        let todayWorked = today?.totalMinutes ?? 0
        let dailyTargetMinutes = max(Int(round(Double(adjustedWeeklyObjectiveMinutes) / Double(activeWeekdaysCount))), 0)
        let todayRemaining = max(dailyTargetMinutes - todayWorked, 0)
        let todayIsWorking = {
            guard let today else { return false }
            guard let hours = currentWeek?.days[today.dateKey]?.hours else { return false }
            return !hours.count.isMultiple(of: 2)
        }()
        let todayRanges = sortedTodayBlocks.map { block in
            WidgetTimeRange(start: block.start, end: block.end)
        }

        let snapshot = WidgetSnapshot(
            totalEffective: totalEffective,
            totalPaid: totalPaid,
            remaining: TimeMath.minutesToHHMM(max(remainingMinutes, 0)),
            progress: progressPercentage,
            isOffline: isOffline,
            lastSync: lastSyncDate ?? .now,
            theme: theme.rawValue,
            accentHex: theme.accentHex,
            accentSecondaryHex: theme.accentSecondaryHex,
            backgroundStartHex: theme.backgroundStartHex,
            backgroundEndHex: theme.backgroundEndHex,
            isLightTheme: theme.isLightTheme,
            todayWorked: TimeMath.minutesToHHMM(todayWorked),
            todayTarget: TimeMath.minutesToHHMM(dailyTargetMinutes),
            todayRemaining: TimeMath.minutesToHHMM(todayRemaining),
            todaySessions: sortedTodayBlocks.count,
            todayFirstIn: sortedTodayBlocks.first?.start,
            todayLastOut: sortedTodayBlocks.last?.end,
            todayRanges: todayRanges,
            todayIsAbsent: today?.absence == .day,
            todayIsWorking: todayIsWorking
        )
        guard snapshot != lastPublishedWidgetSnapshot else { return }
        lastPublishedWidgetSnapshot = snapshot
        WidgetSharedStore.saveSnapshot(snapshot)
        reloadWidgets()
    }

    private func clearWidgetSnapshot() {
        lastPublishedWidgetSnapshot = nil
        WidgetSharedStore.clearSnapshot()
        reloadWidgets()
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "QuelIOWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "QuelIOTodayWidget")
        #endif
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self else { return }
                await MainActor.run {
                    self.nowReference = .now
                }
            }
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("AppViewModel") {
    let viewModel = PreviewFixtures.makeLoggedInViewModel()
    return VStack(alignment: .leading, spacing: 6) {
        Text("Utilisateur: \(viewModel.username)")
        Text("Payé: \(viewModel.totalPaid)")
        Text("Restant: \(TimeMath.minutesToHHMM(max(viewModel.remainingMinutes, 0)))")
        Text("Progression: \(viewModel.progressPercentage)%")
    }
    .font(.caption)
    .padding()
}
#endif
