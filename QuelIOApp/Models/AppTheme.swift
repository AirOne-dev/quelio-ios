import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case midnight
    case light
    case abyss
    case ocean
    case forest
    case sunset
    case lavender
    case christmas

    var id: String { rawValue }

    var label: String {
        switch self {
        case .midnight: return "Midnight"
        case .light: return "Light"
        case .abyss: return "Abyss"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .sunset: return "Sunset"
        case .lavender: return "Lavender"
        case .christmas: return "Christmas"
        }
    }

    var symbol: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        case .abyss: return "sparkles"
        case .ocean: return "water.waves"
        case .forest: return "leaf.fill"
        case .sunset: return "sunset.fill"
        case .lavender: return "wand.and.stars"
        case .christmas: return "gift.fill"
        }
    }

    var accentHex: String {
        switch self {
        case .midnight: return "6366F1"
        case .light: return "6366F1"
        case .abyss: return "3B82F6"
        case .ocean: return "0EA5E9"
        case .forest: return "10B981"
        case .sunset: return "F97316"
        case .lavender: return "A855F7"
        case .christmas: return "DC2626"
        }
    }

    var accentSecondaryHex: String {
        switch self {
        case .midnight: return "818CF8"
        case .light: return "818CF8"
        case .abyss: return "60A5FA"
        case .ocean: return "38BDF8"
        case .forest: return "34D399"
        case .sunset: return "FB923C"
        case .lavender: return "C084FC"
        case .christmas: return "059669"
        }
    }

    var backgroundStartHex: String {
        switch self {
        case .midnight: return "1A1D29"
        case .light: return "F9FAFB"
        case .abyss: return "000000"
        case .ocean: return "1E293B"
        case .forest: return "1A1F1A"
        case .sunset: return "1F1D1A"
        case .lavender: return "1D1A24"
        case .christmas: return "1A0F0F"
        }
    }

    var backgroundEndHex: String {
        switch self {
        case .midnight: return "13151D"
        case .light: return "F3F4F6"
        case .abyss: return "0A0A0A"
        case .ocean: return "0F172A"
        case .forest: return "111411"
        case .sunset: return "141210"
        case .lavender: return "131018"
        case .christmas: return "0F1A0F"
        }
    }

    var isLightTheme: Bool {
        self == .light
    }

    var accent: Color {
        Color(hex: accentHex)
    }

    var accentSecondary: Color {
        Color(hex: accentSecondaryHex)
    }

    var positive: Color {
        switch self {
        case .light: return Color(hex: "059669")
        default: return Color(hex: "22D3EE")
        }
    }

    var danger: Color {
        switch self {
        case .light: return Color(hex: "DC2626")
        case .christmas: return Color(hex: "EF4444")
        default: return Color(hex: "F87171")
        }
    }

    var warning: Color {
        switch self {
        case .light: return Color(hex: "EA580C")
        default: return Color(hex: "F59E0B")
        }
    }

    var surfaceTint: Color {
        switch self {
        case .light: return .black.opacity(0.05)
        default: return .white.opacity(0.10)
        }
    }

    var background: [Color] {
        [Color(hex: backgroundStartHex), Color(hex: backgroundEndHex)]
    }

    var preferredColorScheme: ColorScheme? {
        isLightTheme ? .light : .dark
    }

    static func from(serverValue: String?) -> AppTheme? {
        guard let serverValue else { return nil }
        return AppTheme(rawValue: serverValue)
    }
}

#Preview("Themes") {
    ScrollView {
        VStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                HStack(spacing: 10) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 10, height: 10)
                    Text(theme.label)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(theme.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(theme.surfaceTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding()
    }
}
