import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var navigationBootstrap = false
    @State private var isWeekSectionExpanded = false
    private static let shortSyncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let summaryColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground(theme: viewModel.theme)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if viewModel.isOffline {
                            topStatusRow
                        }

                        weekOverviewSection

                        if !currentDays.isEmpty {
                            UXSectionTitle(title: "Jours", trailing: "\(viewModel.workedDays) actifs")
                                .padding(.top, 6)

                            VStack(spacing: 12) {
                                ForEach(currentDays) { day in
                                    DayCardView(
                                        day: day,
                                        isExpanded: viewModel.isExpanded(day.dateKey),
                                        isFutureMuted: false,
                                        accentStart: viewModel.theme.accent,
                                        onToggleExpand: { viewModel.toggleExpanded(day.dateKey) },
                                        onSetAbsence: { viewModel.setAbsence($0, for: day.dateKey) }
                                    )
                                }
                            }
                        }

                        if !futureDays.isEmpty {
                            UXSectionTitle(title: "À venir", trailing: "\(futureDays.count) jour(s)")

                            VStack(spacing: 10) {
                                ForEach(futureDays) { day in
                                    DayCardView(
                                        day: day,
                                        isExpanded: false,
                                        isFutureMuted: true,
                                        accentStart: viewModel.theme.accent,
                                        onToggleExpand: {},
                                        onSetAbsence: { viewModel.setAbsence($0, for: day.dateKey) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .contentMargins(.bottom, 28)
            }
            .navigationTitle("Ma semaine")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        if (!viewModel.isBusy) {
                            Task { await viewModel.refresh() }
                        }
                    }
                    label: {
                        ReloadToolbarIcon(isAnimating: viewModel.isBusy)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                }
                
                ToolbarSpacer(.flexible, placement: .primaryAction)
                
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                }
            }
        }
        .id(navigationBootstrap)
        .onAppear {
            guard !navigationBootstrap else { return }
            DispatchQueue.main.async {
                navigationBootstrap = true
            }
            viewModel.syncWidgetsFromCurrentState()
        }
    }

    private var topStatusRow: some View {
        HStack(spacing: 8) {
            StatusPill(
                icon: "icloud.slash.fill",
                text: "Hors ligne",
                color: .orange
            )

            Spacer(minLength: 0)
        }
    }

    private var weekOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isWeekSectionExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Semaine en cours")
                        .font(.headline)

                    Spacer()

                    Text("\(viewModel.progressPercentage)%")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(viewModel.theme.accent)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(isWeekSectionExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.22), value: isWeekSectionExpanded)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                weekMetric(title: "Effectif", value: viewModel.totalEffective)
                weekMetric(title: "Payé", value: viewModel.totalPaid)
                weekMetric(title: "Restant", value: TimeMath.minutesToHHMM(max(viewModel.remainingMinutes, 0)))
            }

            ProgressView(value: min(max(viewModel.objectiveCompletion, 0), 1))
                .tint(viewModel.theme.accent)
                .scaleEffect(x: 1, y: 1.3, anchor: .center)

            Text("Objectif \(TimeMath.minutesToHourLabel(viewModel.weeklyObjectiveMinutes)) • Synchro \(shortSyncTime)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if isWeekSectionExpanded {
                Divider()
                    .opacity(0.45)

                if let today = viewModel.todayPresentation {
                    todayFocusBlock(today)
                }

                UXSectionTitle(title: "Résumé", trailing: viewModel.lastSyncLabel)
                    .padding(.top, 2)

                LazyVGrid(columns: summaryColumns, spacing: 10) {
                    summaryDetailTile(
                        title: "Moyenne quotidienne",
                        value: TimeMath.minutesToHourLabel(viewModel.dailyAverageMinutes),
                        subtitle: "jours passés",
                        icon: "calendar.badge.clock",
                        color: viewModel.theme.accent
                    )

                    summaryDetailTile(
                        title: "Progression",
                        value: "\(viewModel.progressPercentage)%",
                        subtitle: viewModel.objectiveDeltaMinutes >= 0
                            ? "avance de +\(TimeMath.minutesToHHMM(viewModel.objectiveDeltaMinutes))"
                            : "retard de \(TimeMath.minutesToHHMM(viewModel.remainingMinutes))",
                        icon: "chart.line.uptrend.xyaxis",
                        color: viewModel.theme.accent
                    )

                    summaryDetailTile(
                        title: "Session moyenne",
                        value: TimeMath.minutesToHourLabel(viewModel.averageSessionMinutes),
                        subtitle: "\(viewModel.dayPresentations.flatMap(\.timeBlocks).count) sessions",
                        icon: "timer",
                        color: viewModel.theme.accent
                    )

                    summaryDetailTile(
                        title: "Temps de pause",
                        value: TimeMath.minutesToHourLabel(viewModel.weekPauseMinutes),
                        subtitle: "sur la semaine",
                        icon: "cup.and.saucer.fill",
                        color: viewModel.theme.accent
                    )
                }
            }
        }
        .padding(18)
        .cardSurface(cornerRadius: 20)
    }

    private func todayFocusBlock(_ day: DayPresentation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Aujourd'hui")
                    .font(.subheadline.weight(.semibold))
                Text(day.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeMath.minutesToHHMM(viewModel.todayWorkedMinutes))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                Text("pointé")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryDetailTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 108)
        .padding(12)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func weekMetric(title: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(valueColor)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var shortSyncTime: String {
        guard let lastSyncDate = viewModel.lastSyncDate else { return "-" }
        return Self.shortSyncFormatter.string(from: lastSyncDate)
    }

    private var currentDays: [DayPresentation] {
        viewModel.dayPresentations.filter { !isFutureDay($0) }
    }

    private var futureDays: [DayPresentation] {
        viewModel.dayPresentations.filter(isFutureDay(_:))
    }

    private func isFutureDay(_ day: DayPresentation) -> Bool {
        guard let date = Date.parseDataDate(day.dateKey) else { return false }
        return date > Calendar.current.startOfDay(for: .now)
    }
}

private struct ReloadToolbarIcon: View {
    let isAnimating: Bool

    var body: some View {
        if isAnimating {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(rotation(for: context.date)))
            }
        } else {
            Image(systemName: "arrow.clockwise")
        }
    }

    private func rotation(for date: Date) -> Double {
        let cycleDuration = 0.85
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
        return (elapsed / cycleDuration) * 360
    }
}

#Preview("Dashboard") {
    let viewModel = PreviewFixtures.makeLoggedInViewModel()
    PreviewHost(viewModel: viewModel) {
        DashboardView(viewModel: viewModel)
    }
}

#Preview("Dashboard Hors Ligne") {
    let viewModel = PreviewFixtures.makeLoggedInViewModel(
        offline: true,
        expansionMode: .collapsed
    )
    PreviewHost(viewModel: viewModel) {
        DashboardView(viewModel: viewModel)
    }
}
