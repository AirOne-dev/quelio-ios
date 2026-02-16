import Foundation

final class SessionStore {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let username = "quelio_username"
        static let apiBaseURL = "quelio_api_base_url"
        static let themePrefix = "quelio_theme_"
        static let objectivePrefix = "quelio_objective_"
        static let tokenPrefix = "quelio_token_"
        static let absencesPrefix = "quelio_absences_"
    }

    func loadUsername() -> String? {
        defaults.string(forKey: Keys.username)
    }

    func saveUsername(_ username: String) {
        defaults.set(username, forKey: Keys.username)
    }

    func loadAPIBaseURL() -> String {
        defaults.string(forKey: Keys.apiBaseURL) ?? "http://localhost:8080/"
    }

    func saveAPIBaseURL(_ url: String) {
        defaults.set(url, forKey: Keys.apiBaseURL)
    }

    func loadToken(for username: String) -> String? {
        defaults.string(forKey: Keys.tokenPrefix + username)
    }

    func saveToken(_ token: String, for username: String) {
        defaults.set(token, forKey: Keys.tokenPrefix + username)
    }

    func removeToken(for username: String) {
        defaults.removeObject(forKey: Keys.tokenPrefix + username)
    }

    func loadTheme(for username: String) -> AppTheme {
        let raw = defaults.string(forKey: Keys.themePrefix + username) ?? AppTheme.ocean.rawValue
        return AppTheme(rawValue: raw) ?? .ocean
    }

    func saveTheme(_ theme: AppTheme, for username: String) {
        defaults.set(theme.rawValue, forKey: Keys.themePrefix + username)
    }

    func loadObjective(for username: String) -> Int {
        let value = defaults.integer(forKey: Keys.objectivePrefix + username)
        return value == 0 ? 2_280 : value
    }

    func saveObjective(_ minutes: Int, for username: String) {
        defaults.set(minutes, forKey: Keys.objectivePrefix + username)
    }

    func loadAbsences(for username: String) -> [String: AbsenceSection] {
        let raw = defaults.dictionary(forKey: Keys.absencesPrefix + username) as? [String: String] ?? [:]
        return raw.reduce(into: [:]) { result, item in
            if let section = AbsenceSection(rawValue: item.value) {
                result[item.key] = section
            }
        }
    }

    func saveAbsences(_ absences: [String: AbsenceSection], for username: String) {
        let raw = absences.reduce(into: [String: String]()) { partial, item in
            partial[item.key] = item.value.rawValue
        }
        defaults.set(raw, forKey: Keys.absencesPrefix + username)
    }
}

#if DEBUG
import SwiftUI

#Preview("SessionStore") {
    VStack(alignment: .leading, spacing: 6) {
        Text("API locale: \(SessionStore().loadAPIBaseURL())")
        Text("Theme défaut: \(SessionStore().loadTheme(for: "preview").label)")
    }
    .font(.caption)
    .padding()
}
#endif
