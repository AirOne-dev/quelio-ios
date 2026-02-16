import SwiftUI

struct TimelineView: View {
    let blocks: [TimeBlock]
    let accentStart: Color

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let nowProgress = nowTimelineProgress

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.10))
                        .frame(height: 12)

                    HStack(spacing: 0) {
                        ForEach(0..<12, id: \.self) { index in
                            Rectangle()
                                .fill(index.isMultiple(of: 2) ? Color.primary.opacity(0.05) : Color.clear)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .clipShape(Capsule())
                    .frame(height: 12)

                    ForEach(blocks) { block in
                        let start = TimeMath.timelineOffset(block.start)
                        let end = TimeMath.timelineOffset(block.end)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accentStart)
                            .frame(
                                width: max((end - start) * proxy.size.width, 4),
                                height: 12
                            )
                            .offset(x: start * proxy.size.width)
                    }

                    if nowProgress > 0, nowProgress < 1 {
                        Rectangle()
                            .fill(accentStart.opacity(0.90))
                            .frame(width: 1.5, height: 16)
                            .offset(x: nowProgress * proxy.size.width)
                            .overlay(alignment: .top) {
                                Circle()
                                    .fill(accentStart)
                                    .frame(width: 4, height: 4)
                                    .offset(y: -5)
                            }
                    }
                }
            }
            .frame(height: 14)

            HStack {
                Text("08")
                Spacer()
                Text("10")
                Spacer()
                Text("12")
                Spacer()
                Text("14")
                Spacer()
                Text("16")
                Spacer()
                Text("18")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var nowTimelineProgress: Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let span = Double(TimeMath.endOfDayMinutes - TimeMath.startOfDayMinutes)
        return Double(minutes - TimeMath.startOfDayMinutes) / span
    }
}

#Preview("Timeline") {
    PreviewHost(viewModel: PreviewFixtures.makeLoggedInViewModel()) {
        TimelineView(
            blocks: PreviewFixtures.sampleTimelineBlocks,
            accentStart: .green
        )
        .padding()
        .cardSurface(cornerRadius: 16)
        .padding()
    }
}
