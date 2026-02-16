import SwiftUI
import WidgetKit

struct QuelIOWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct QuelIOWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuelIOWidgetEntry {
        QuelIOWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuelIOWidgetEntry) -> Void) {
        completion(makeEntry(for: .now, fallbackToPlaceholder: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuelIOWidgetEntry>) -> Void) {
        let now = Date()
        let entries = (0..<6).compactMap { index -> QuelIOWidgetEntry? in
            guard let date = Calendar.current.date(byAdding: .minute, value: index * 10, to: now) else {
                return nil
            }
            return makeEntry(for: date, fallbackToPlaceholder: false)
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(for date: Date, fallbackToPlaceholder: Bool) -> QuelIOWidgetEntry {
        let sharedSnapshot = WidgetSharedStore.loadSnapshot()
        if let sharedSnapshot {
            return QuelIOWidgetEntry(date: date, snapshot: sharedSnapshot)
        }

        if fallbackToPlaceholder {
            return QuelIOWidgetEntry(date: date, snapshot: .placeholder)
        }

        return QuelIOWidgetEntry(date: date, snapshot: nil)
    }
}

private struct WidgetPalette {
    let accent: Color
    let accentSecondary: Color
    let backgroundStart: Color
    let backgroundEnd: Color
    let isLightTheme: Bool

    init(snapshot: WidgetSnapshot?) {
        accent = Color(widgetHex: snapshot?.accentHex) ?? Color(widgetHex: "0EA5E9") ?? .blue
        accentSecondary = Color(widgetHex: snapshot?.accentSecondaryHex) ?? Color(widgetHex: "38BDF8") ?? .cyan
        backgroundStart = Color(widgetHex: snapshot?.backgroundStartHex) ?? Color(widgetHex: "1E293B") ?? .black
        backgroundEnd = Color(widgetHex: snapshot?.backgroundEndHex) ?? Color(widgetHex: "0F172A") ?? .black.opacity(0.9)
        isLightTheme = snapshot?.isLightTheme ?? false
    }

    var primaryText: Color {
        isLightTheme ? Color.black.opacity(0.86) : Color.white
    }

    var secondaryText: Color {
        isLightTheme ? Color.black.opacity(0.62) : Color.white.opacity(0.72)
    }

    var surfaceTint: Color {
        isLightTheme ? Color.black.opacity(0.05) : Color.white.opacity(0.10)
    }

    var cardFill: Color {
        isLightTheme ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
    }
}

struct WeeklyEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuelIOWidgetEntry

    private var palette: WidgetPalette {
        WidgetPalette(snapshot: entry.snapshot)
    }

    private var snapshotValue: WidgetSnapshot {
        entry.snapshot ?? .placeholder
    }

    private var isDisconnected: Bool {
        entry.snapshot == nil
    }

    var body: some View {
        Group {
            if isDisconnected {
                disconnectedContent
            } else {
                connectedContent
            }
        }
        .containerBackground(for: .widget) {
            backgroundLayer
        }
    }

    private var connectedContent: some View {
        Group {
            switch family {
            case .systemSmall:
                connectedSmallView
            default:
                connectedMediumView
            }
        }
    }

    private var disconnectedContent: some View {
        Group {
            switch family {
            case .systemSmall:
                disconnectedSmallView
            default:
                disconnectedMediumView
            }
        }
    }

    private var backgroundLayer: some View {
        WidgetThemeBackground(palette: palette)
    }

    private var connectedSmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Semaine")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)

                Spacer(minLength: 0)

                if snapshotValue.isOffline {
                    statusChip("Hors ligne", color: .orange)
                } else {
                    statusChip("\(snapshotValue.progress)%", color: palette.accent)
                }
            }

            Text(snapshotValue.totalPaid)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(palette.primaryText)

            HStack(spacing: 8) {
                miniMetric(title: "Effectif", value: snapshotValue.totalEffective)
                Spacer(minLength: 0)
                miniMetric(title: "Restant", value: snapshotValue.remaining)
            }

            ProgressView(value: Double(snapshotValue.progress), total: 100)
                .tint(palette.accent)
        }
        .padding(14)
    }

    private var connectedMediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Quel io • Semaine")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Spacer(minLength: 0)

                if snapshotValue.isOffline {
                    statusChip("Hors ligne", color: .orange)
                } else {
                    statusChip("\(snapshotValue.progress)%", color: palette.accent)
                }
            }

            HStack(spacing: 8) {
                metricCard(title: "Effectif", value: snapshotValue.totalEffective)
                metricCard(title: "Payé", value: snapshotValue.totalPaid)
                metricCard(title: "Restant", value: snapshotValue.remaining)
            }

            ProgressView(value: Double(snapshotValue.progress), total: 100)
                .tint(palette.accent)
        }
        .padding(14)
    }

    private var disconnectedSmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Semaine")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: 0)
                statusChip("Déconnecté", color: .gray)
            }

            Image(systemName: "lock.shield")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Text("Connecte-toi dans l'app")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)

            Text("pour afficher ta semaine.")
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
        }
        .padding(14)
    }

    private var disconnectedMediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Quel io • Semaine")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 0)
                statusChip("Déconnecté", color: .gray)
            }

            HStack(spacing: 8) {
                metricCard(title: "Effectif", value: "--:--")
                metricCard(title: "Payé", value: "--:--")
                metricCard(title: "Restant", value: "--:--")
            }

            Label("Ouvre l'app pour te reconnecter.", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(14)
    }

    private func miniMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)

            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(palette.cardFill, in: Capsule())
    }

    private func statusChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(palette.isLightTheme ? 0.2 : 0.28), in: Capsule())
    }
}

struct TodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuelIOWidgetEntry

    private var palette: WidgetPalette {
        WidgetPalette(snapshot: entry.snapshot)
    }

    private var snapshotValue: WidgetSnapshot {
        entry.snapshot ?? .placeholder
    }

    private var isDisconnected: Bool {
        entry.snapshot == nil
    }

    private var worked: String {
        snapshotValue.todayWorked ?? "00:00"
    }

    private var sessions: Int {
        snapshotValue.todaySessions ?? 0
    }

    private var firstIn: String {
        firstInRaw ?? "--:--"
    }

    private var lastOut: String {
        lastOutRaw ?? "--:--"
    }

    private var firstInRaw: String? {
        snapshotValue.todayFirstIn
    }

    private var lastOutRaw: String? {
        snapshotValue.todayLastOut
    }

    private var ranges: [WidgetTimeRange] {
        snapshotValue.todayRanges ?? []
    }

    private var isAbsent: Bool {
        snapshotValue.todayIsAbsent ?? false
    }

    private var isWorking: Bool {
        snapshotValue.todayIsWorking ?? false
    }

    private var hasClockEvents: Bool {
        minutes(from: worked) > 0
            || sessions > 0
            || !ranges.isEmpty
            || snapshotValue.todayFirstIn != nil
            || snapshotValue.todayLastOut != nil
    }

    private var isDayNotStarted: Bool {
        guard !isDisconnected else { return false }
        guard !isAbsent else { return false }
        return !hasClockEvents
    }

    private var sessionSpanText: String {
        let fallbackStart = ranges.first?.start
        let fallbackEnd = ranges.last?.end
        let start = firstInRaw ?? fallbackStart
        let end = lastOutRaw ?? fallbackEnd

        switch (start, end) {
        case let (.some(start), .some(end)):
            return "\(start)-\(end)"
        case let (.some(start), .none):
            return "Depuis \(start)"
        case let (.none, .some(end)):
            return "Jusqu'à \(end)"
        default:
            return "--:--"
        }
    }

    private var statusText: String {
        if isAbsent { return "Absent" }
        if isDayNotStarted { return "Pas commencé" }
        if isWorking { return "En cours" }
        if !hasClockEvents { return "Aucun pointage" }
        return "Terminé"
    }

    private var statusColor: Color {
        if isAbsent { return .orange }
        if isDayNotStarted { return palette.accentSecondary }
        if isWorking { return palette.accent }
        if !hasClockEvents { return .gray }
        return .green
    }

    var body: some View {
        Group {
            if isDisconnected {
                disconnectedContent
            } else if isDayNotStarted {
                notStartedContent
            } else {
                activeContent
            }
        }
        .containerBackground(for: .widget) {
            backgroundLayer
        }
    }

    private var activeContent: some View {
        Group {
            switch family {
            case .systemSmall:
                activeSmallView
            default:
                activeMediumView
            }
        }
    }

    private var disconnectedContent: some View {
        Group {
            switch family {
            case .systemSmall:
                disconnectedSmallView
            default:
                disconnectedMediumView
            }
        }
    }

    private var notStartedContent: some View {
        Group {
            switch family {
            case .systemSmall:
                notStartedSmallView
            default:
                notStartedMediumView
            }
        }
    }

    private var backgroundLayer: some View {
        WidgetThemeBackground(palette: palette)
    }

    private var activeSmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Aujourd'hui")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: 0)
                statusChip(statusText, color: statusColor)
            }

            Text(worked)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(palette.primaryText)

            WidgetPunchTimeline(ranges: ranges, palette: palette)
                .frame(height: 10)

            HStack(spacing: 8) {
                miniMetric(title: "Sessions", value: "\(sessions)")
                Spacer(minLength: 0)
                miniMetric(title: "Plage", value: sessionSpanText)
            }
        }
        .padding(14)
    }

    private var activeMediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Quel io • Aujourd'hui")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 0)
                statusChip(statusText, color: statusColor)
            }

            HStack(spacing: 8) {
                metricCard(title: "Travaillé", value: worked)
                metricCard(title: "Sessions", value: "\(sessions)")
                metricCard(title: "Plage", value: sessionSpanText)
            }

            WidgetPunchTimeline(ranges: ranges, palette: palette)
                .frame(height: 10)

            HStack(spacing: 8) {
                Text(firstIn)
                Spacer(minLength: 0)
                Text(lastOut)
            }
            .font(.caption2)
            .foregroundStyle(palette.secondaryText)
            .lineLimit(1)
        }
        .padding(14)
    }

    private var disconnectedSmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Aujourd'hui")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: 0)
                statusChip("Déconnecté", color: .gray)
            }

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Text("Connecte-toi pour suivre")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)

            Text("ta journée en direct.")
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(14)
    }

    private var disconnectedMediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Quel io • Aujourd'hui")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 0)
                statusChip("Déconnecté", color: .gray)
            }

            HStack(spacing: 8) {
                metricCard(title: "Pointé", value: "--:--")
                metricCard(title: "Sessions", value: "--")
                metricCard(title: "Plage", value: "--:--")
            }

            Label("Ouvre l'app pour afficher ta journée.", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(14)
    }

    private var notStartedSmallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Aujourd'hui")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                Spacer(minLength: 0)
                statusChip("Pas commencé", color: palette.accentSecondary)
            }

            Label("Aucun pointage", systemImage: "clock.badge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            WidgetPunchTimeline(ranges: [], palette: palette)
                .frame(height: 10)

            HStack(spacing: 8) {
                miniMetric(title: "Pointé", value: "00:00")
                Spacer(minLength: 0)
                miniMetric(title: "Sessions", value: "0")
            }
        }
        .padding(14)
    }

    private var notStartedMediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Quel io • Aujourd'hui")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer(minLength: 0)
                statusChip("Pas commencé", color: palette.accentSecondary)
            }

            HStack(spacing: 8) {
                metricCard(title: "Travaillé", value: "00:00")
                metricCard(title: "Sessions", value: "0")
                metricCard(title: "Plage", value: "--:--")
            }

            WidgetPunchTimeline(ranges: [], palette: palette)
                .frame(height: 10)

            Label("Aucun pointage détecté pour le moment.", systemImage: "clock.badge")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(14)
    }

    private func miniMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)

            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(palette.cardFill, in: Capsule())
    }

    private func statusChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(palette.isLightTheme ? 0.2 : 0.28), in: Capsule())
    }

    private func minutes(from hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return 0 }
        return (parts[0] * 60) + parts[1]
    }
}

private struct WidgetPunchTimeline: View {
    let ranges: [WidgetTimeRange]
    let palette: WidgetPalette

    private var validRanges: [(start: Int, end: Int)] {
        ranges.compactMap { range in
            let start = minutes(from: range.start)
            let end = minutes(from: range.end)
            guard start >= 0, end > start else { return nil }
            return (start, end)
        }
    }

    private var domain: ClosedRange<Int> {
        let fallbackStart = 8 * 60
        let fallbackEnd = 18 * 60
        guard !validRanges.isEmpty else { return fallbackStart...fallbackEnd }

        var lower = min(validRanges.map(\.start).min() ?? fallbackStart, fallbackStart)
        var upper = max(validRanges.map(\.end).max() ?? fallbackEnd, fallbackEnd)
        if upper - lower < 240 {
            let center = (upper + lower) / 2
            lower = center - 120
            upper = center + 120
        }
        return lower...upper
    }

    private var normalizedSegments: [ClosedRange<Double>] {
        let bounds = domain
        let total = Double(max(bounds.upperBound - bounds.lowerBound, 1))

        return validRanges.compactMap { range in
            let start = max(bounds.lowerBound, min(range.start, bounds.upperBound))
            let end = max(start, min(range.end, bounds.upperBound))

            let lower = Double(start - bounds.lowerBound) / total
            let upper = Double(end - bounds.lowerBound) / total
            guard upper > lower else { return nil }
            return lower...upper
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.cardFill.opacity(0.82))

                ForEach(Array(normalizedSegments.enumerated()), id: \.offset) { _, segment in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(proxy.size.width * CGFloat(segment.upperBound - segment.lowerBound), 5),
                            height: proxy.size.height
                        )
                        .offset(x: proxy.size.width * CGFloat(segment.lowerBound))
                }
            }
            .overlay {
                if normalizedSegments.isEmpty {
                    Capsule()
                        .stroke(
                            palette.secondaryText.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                }
            }
        }
    }

    private func minutes(from hhmm: String) -> Int {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return -1 }
        let hours = parts[0]
        let minutes = parts[1]
        guard (0...23).contains(hours), (0...59).contains(minutes) else { return -1 }
        return (hours * 60) + minutes
    }
}

private struct WidgetThemeBackground: View {
    let palette: WidgetPalette

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let base = min(width, height)

            ZStack {
                LinearGradient(
                    colors: [palette.backgroundStart, palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )

                orb(color: palette.accent, size: base * 1.1, opacity: palette.isLightTheme ? 0.46 : 0.70)
                    .offset(x: -width * 0.26, y: -height * 0.38)

                orb(color: palette.accentSecondary, size: base * 0.94, opacity: palette.isLightTheme ? 0.40 : 0.58)
                    .offset(x: width * 0.34, y: -height * 0.30)

                orb(color: palette.accent, size: base * 0.86, opacity: palette.isLightTheme ? 0.28 : 0.42)
                    .offset(x: -width * 0.14, y: height * 0.38)

                orb(color: .orange, size: base * 0.74, opacity: palette.isLightTheme ? 0.22 : 0.34)
                    .offset(x: width * 0.26, y: height * 0.42)

                LinearGradient(
                    colors: [palette.surfaceTint.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .frame(width: width, height: height)
            .clipped()
        }
    }

    private func orb(color: Color, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(opacity),
                        color.opacity(opacity * 0.44),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.52
                )
            )
            .frame(width: size, height: size)
            .blur(radius: palette.isLightTheme ? 40 : 52)
    }
}

struct QuelIOWidget: Widget {
    let kind = "QuelIOWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuelIOWidgetProvider()) { entry in
            WeeklyEntryView(entry: entry)
        }
        .configurationDisplayName("Quel io • Semaine")
        .description("Vue rapide de ta semaine en cours.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuelIOTodayWidget: Widget {
    let kind = "QuelIOTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuelIOWidgetProvider()) { entry in
            TodayEntryView(entry: entry)
        }
        .configurationDisplayName("Quel io • Aujourd'hui")
        .description("Temps de la journée actuelle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension Color {
    init?(widgetHex: String?) {
        guard let widgetHex else { return nil }
        let sanitized = widgetHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 3 || sanitized.count == 6 else { return nil }

        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)

        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch sanitized.count {
        case 3:
            red = ((int >> 8) & 0xF) * 17
            green = ((int >> 4) & 0xF) * 17
            blue = (int & 0xF) * 17
        default:
            red = (int >> 16) & 0xFF
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

#Preview("Semaine Small", as: .systemSmall) {
    QuelIOWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: .previewForest)
}

#Preview("Semaine Medium", as: .systemMedium) {
    QuelIOWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: .previewForest)
}

#Preview("Semaine Déconnecté", as: .systemMedium) {
    QuelIOWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: nil)
}

#Preview("Aujourd'hui Small", as: .systemSmall) {
    QuelIOTodayWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: .previewForest)
}

#Preview("Aujourd'hui Medium", as: .systemMedium) {
    QuelIOTodayWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: .previewForest)
}

#Preview("Aujourd'hui Pas commencé", as: .systemMedium) {
    QuelIOTodayWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: .previewDayNotStarted)
}

#Preview("Aujourd'hui Déconnecté", as: .systemSmall) {
    QuelIOTodayWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: nil)
}
