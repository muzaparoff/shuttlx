import WidgetKit
import SwiftUI

@main
struct ShuttlXWatchWidgets: WidgetBundle {
    var body: some Widget {
        LastWorkoutComplication()
        WeeklyProgressComplication()
        QuickStartComplication()
        TodayWorkoutComplication()
    }
}
