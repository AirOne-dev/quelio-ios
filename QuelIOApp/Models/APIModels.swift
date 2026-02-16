import Foundation

struct KelioAPIResponse: Decodable {
    var preferences: UserPreferences?
    var token: String?
    var weeks: [String: WeekPayload]
    var error: String?

    enum CodingKeys: String, CodingKey {
        case preferences
        case token
        case weeks
        case error
        case hours
        case totalEffective = "total_effective"
        case totalPaid = "total_paid"
    }

    init(
        preferences: UserPreferences? = nil,
        token: String? = nil,
        weeks: [String: WeekPayload] = [:],
        error: String? = nil
    ) {
        self.preferences = preferences
        self.token = token
        self.weeks = weeks
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // API can return preferences as {} or [].
        preferences = try? container.decode(UserPreferences.self, forKey: .preferences)
        token = try? container.decode(String.self, forKey: .token)
        error = try? container.decode(String.self, forKey: .error)

        if let decodedWeeks = try? container.decode([String: WeekPayload].self, forKey: .weeks) {
            weeks = decodedWeeks
            return
        }

        // Legacy format support:
        // {
        //   "hours": { "dd-MM-yyyy": ["08:30", ...] },
        //   "total_effective": "xx:yy",
        //   "total_paid": "xx:yy"
        // }
        if let legacyHours = try container.decodeIfPresent([String: [String]].self, forKey: .hours) {
            let dayMap = legacyHours.mapValues { DayPayload(hours: $0) }
            let totalEffective = try container.decodeIfPresent(String.self, forKey: .totalEffective) ?? "00:00"
            let totalPaid = try container.decodeIfPresent(String.self, forKey: .totalPaid) ?? totalEffective
            let weekKey = Date.currentISOWeekKey()
            weeks = [weekKey: WeekPayload(days: dayMap, totalEffective: totalEffective, totalPaid: totalPaid)]
            return
        }

        weeks = [:]
    }
}

struct UserPreferences: Codable {
    var theme: String?
    var minutesObjective: Int?

    enum CodingKeys: String, CodingKey {
        case theme
        case minutesObjective = "minutes_objective"
    }
}

struct WeekPayload: Decodable {
    var days: [String: DayPayload]
    var totalEffective: String
    var totalPaid: String

    enum CodingKeys: String, CodingKey {
        case days
        case totalEffective = "total_effective"
        case totalPaid = "total_paid"
    }

    init(days: [String: DayPayload], totalEffective: String, totalPaid: String) {
        self.days = days
        self.totalEffective = totalEffective
        self.totalPaid = totalPaid
    }
}

struct DayPayload: Decodable {
    var hours: [String]
    var effective: String?
    var paid: String?

    enum CodingKeys: String, CodingKey {
        case hours
        case effective
        case paid
    }

    init(hours: [String], effective: String? = nil, paid: String? = nil) {
        self.hours = hours
        self.effective = effective
        self.paid = paid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hours = try container.decodeIfPresent([String].self, forKey: .hours) ?? []
        effective = try container.decodeIfPresent(String.self, forKey: .effective)
        paid = try container.decodeIfPresent(String.self, forKey: .paid)
    }
}

struct APIErrorEnvelope: Decodable {
    let error: String?
    let tokenInvalidated: Bool?

    enum CodingKeys: String, CodingKey {
        case error
        case tokenInvalidated = "token_invalidated"
    }
}

#if DEBUG
import SwiftUI

#Preview("API Models") {
    let payload = PreviewFixtures.payload
    return VStack(alignment: .leading, spacing: 8) {
        Text("Semaines: \(payload.weeks.count)")
        Text("Objectif: \(payload.preferences?.minutesObjective ?? 0) min")
        Text("Theme: \(payload.preferences?.theme ?? "-")")
    }
    .font(.caption)
    .padding()
}
#endif
