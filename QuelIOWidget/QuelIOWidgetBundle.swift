import WidgetKit
import SwiftUI

@main
struct QuelIOWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuelIOWidget()
        QuelIOTodayWidget()
    }
}

#Preview("Bundle - Semaine", as: .systemSmall) {
    QuelIOWidget()
} timeline: {
    QuelIOWidgetEntry(date: .now, snapshot: .previewForest)
}
