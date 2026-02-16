import SwiftUI

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)

        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch sanitized.count {
        case 3:
            r = ((int >> 8) & 0xF) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

#Preview("Color Hex") {
    HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: "10B981"))
            .frame(width: 48, height: 32)
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: "F97316"))
            .frame(width: 48, height: 32)
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: "6366F1"))
            .frame(width: 48, height: 32)
    }
    .padding()
}
