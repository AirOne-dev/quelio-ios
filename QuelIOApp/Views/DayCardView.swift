import SwiftUI

struct DayCardView: View {
    let day: DayPresentation
    let isExpanded: Bool
    let isFutureMuted: Bool
    let accentStart: Color
    let onToggleExpand: () -> Void
    let onSetAbsence: (AbsenceSection) -> Void
    private let presenceTapExclusionWidth: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            if !isOpen, let windowLabel {
                compactWindowRow(windowLabel)
            }

            if isOpen {
                Divider()
                    .opacity(0.45)

                if day.timeBlocks.isEmpty {
                    emptyStateRow
                } else {
                    if !day.isFullyAbsent {
                        TimelineView(blocks: day.timeBlocks, accentStart: accentStart)
                    }

                    HStack(spacing: 8) {
                        metricView(title: "Sessions", value: "\(day.timeBlocks.count)")
                        metricView(title: "Amplitude", value: TimeMath.minutesToHourLabel(amplitudeMinutes))
                        metricView(title: "Pauses", value: TimeMath.minutesToHourLabel(pauseMinutes))
                    }

                    VStack(spacing: 6) {
                        ForEach(Array(sortedBlocks.enumerated()), id: \.element.id) { index, block in
                            sessionRow(index: index + 1, block: block)
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardSurface(cornerRadius: 18)
        .overlay {
            ZStack {
                if isFutureMuted {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.primary.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }

                if isToday {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accentStart.opacity(0.75), lineWidth: 1.4)
                }
            }
        }
        .saturation(isFutureMuted ? 0.9 : 1)
        .opacity(cardOpacity)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    guard canExpand else { return }
                    // Keep presence control tap dedicated to absence menu only.
                    guard value.location.x > presenceTapExclusionWidth else { return }
                    withAnimation(.easeInOut(duration: 0.20)) {
                        onToggleExpand()
                    }
                }
        )
    }

    private var leadingControl: some View {
        Menu {
            Section("Présence du jour") {
                ForEach(AbsenceSection.allCases, id: \.self) { section in
                    Button {
                        onSetAbsence(section)
                    } label: {
                        HStack {
                            Label(menuTitle(for: section), systemImage: iconName(for: section))
                            Spacer(minLength: 8)
                            if section == day.absence {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: leadingIconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(leadingIconColor)
                .frame(width: 32, height: 32)
                .background(leadingControlBackground, in: Circle())
                .overlay {
                    Circle()
                        .stroke(leadingControlStroke, lineWidth: 1)
                }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingControl

            VStack(alignment: .leading, spacing: 4) {
                Text(day.title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                if day.totalMinutes > 0 {
                    Text(TimeMath.minutesToHHMM(day.totalMinutes))
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text(trailingLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if day.absence != .none {
                    Text(day.absence.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.2), in: Capsule())
                }
            }

            if canExpand {
                Image(systemName: "chevron.down")
                    .font(.footnote.bold())
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .animation(.easeInOut(duration: 0.20), value: isOpen)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compactWindowRow(_ label: String) -> some View {
        HStack(spacing: 8) {
            Label(label, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if pauseMinutes > 0 {
                Text("Pause \(TimeMath.minutesToHourLabel(pauseMinutes))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private var emptyStateRow: some View {
        HStack(spacing: 8) {
            Image(systemName: day.isPast ? "exclamationmark.bubble.fill" : "clock.badge.questionmark")
                .foregroundStyle(.secondary)
            Text(day.isPast ? "Aucun pointage détecté sur cette journée." : "Aucun pointage pour le moment.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()
        }
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func sessionRow(index: Int, block: TimeBlock) -> some View {
        HStack(spacing: 10) {
            Text("\(index).")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)

            Label(block.start, systemImage: iconForSession(start: block.start))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(block.end)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(TimeMath.minutesToHourLabel(block.durationMinutes))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var cardOpacity: Double {
        if day.isFullyAbsent { return 0.72 }
        if isFutureMuted { return 0.88 }
        return 1
    }

    private var canExpand: Bool {
        !isFutureMuted && !day.timeBlocks.isEmpty
    }

    private var isOpen: Bool {
        canExpand && isExpanded
    }

    private var windowLabel: String? {
        guard !isOpen, let first = sortedBlocks.first, let last = sortedBlocks.last else { return nil }
        return "\(first.start) - \(last.end)"
    }

    private var trailingLabel: String {
        if day.isFullyAbsent { return "Absent" }
        if day.isPartiallyAbsent { return day.absence.label }
        if isFutureMuted { return "À venir" }
        if day.isPast && day.timeBlocks.isEmpty { return "Manquant" }
        return "—"
    }

    private var subtitle: String {
        if day.isFullyAbsent { return "Absence toute la journée" }
        if day.isPartiallyAbsent { return "Absence \(day.absence.label.lowercased())" }
        if isFutureMuted { return "Journée à venir" }
        if day.timeBlocks.isEmpty {
            return day.isPast ? "Aucun pointage sur cette journée" : "Journée en cours"
        }
        return "\(day.timeBlocks.count) session\(day.timeBlocks.count > 1 ? "s" : "")"
    }

    private var leadingIconName: String {
        if day.absence != .none {
            return iconName(for: day.absence)
        }
        return isFutureMuted ? "calendar.badge.clock" : iconName(for: .none)
    }

    private var leadingIconColor: Color {
        if day.absence != .none { return .orange }
        return accentStart
    }

    private var leadingControlBackground: Color {
        if day.absence != .none {
            return .orange.opacity(0.18)
        }
        return accentStart.opacity(0.14)
    }

    private var leadingControlStroke: Color {
        if day.absence != .none { return .orange.opacity(0.38) }
        return accentStart.opacity(0.45)
    }

    private var sortedBlocks: [TimeBlock] {
        day.timeBlocks.sorted { lhs, rhs in
            TimeMath.timeToMinutes(lhs.start) < TimeMath.timeToMinutes(rhs.start)
        }
    }

    private var pauseMinutes: Int {
        guard sortedBlocks.count > 1 else { return 0 }

        var total = 0
        for index in 0..<(sortedBlocks.count - 1) {
            let previousEnd = TimeMath.timeToMinutes(sortedBlocks[index].end)
            let nextStart = TimeMath.timeToMinutes(sortedBlocks[index + 1].start)
            total += max(0, nextStart - previousEnd)
        }
        return total
    }

    private var amplitudeMinutes: Int {
        guard let first = sortedBlocks.first, let last = sortedBlocks.last else { return 0 }
        return max(0, TimeMath.timeToMinutes(last.end) - TimeMath.timeToMinutes(first.start))
    }

    private func iconForSession(start: String) -> String {
        let minutes = TimeMath.timeToMinutes(start)
        if minutes < 12 * 60 { return "sunrise.fill" }
        if minutes < 17 * 60 { return "sun.max.fill" }
        return "moon.stars.fill"
    }

    private func iconName(for section: AbsenceSection) -> String {
        switch section {
        case .none: return "person.crop.circle.badge.checkmark"
        case .day: return "person.crop.circle.badge.xmark"
        case .morning: return "sunrise.fill"
        case .afternoon: return "sunset.fill"
        }
    }

    private func menuTitle(for section: AbsenceSection) -> String {
        switch section {
        case .none: return "Présent"
        case .day: return "Absent - toute la journée"
        case .morning: return "Absent - matin"
        case .afternoon: return "Absent - après-midi"
        }
    }

    private var isToday: Bool {
        guard let date = Date.parseDataDate(day.dateKey) else { return false }
        return Calendar.current.isDateInToday(date)
    }
}

#Preview("DayCard") {
    let day = PreviewFixtures.sampleExpandedDay
    return PreviewHost(viewModel: PreviewFixtures.makeLoggedInViewModel()) {
        DayCardView(
            day: day,
            isExpanded: false,
            isFutureMuted: false,
            accentStart: .green,
            onToggleExpand: {},
            onSetAbsence: { _ in }
        )
        .padding()
    }
}

#Preview("DayCard Ouverte") {
    let day = PreviewFixtures.sampleExpandedDay
    return PreviewHost(viewModel: PreviewFixtures.makeLoggedInViewModel()) {
        DayCardView(
            day: day,
            isExpanded: true,
            isFutureMuted: false,
            accentStart: .green,
            onToggleExpand: {},
            onSetAbsence: { _ in }
        )
        .padding()
    }
}

#Preview("DayCard Future") {
    let day = PreviewFixtures.sampleFutureDay
    return PreviewHost(viewModel: PreviewFixtures.makeLoggedInViewModel()) {
        DayCardView(
            day: day,
            isExpanded: false,
            isFutureMuted: true,
            accentStart: .green,
            onToggleExpand: {},
            onSetAbsence: { _ in }
        )
        .padding()
    }
}
