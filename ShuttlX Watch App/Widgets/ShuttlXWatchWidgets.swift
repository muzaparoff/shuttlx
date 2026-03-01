import WidgetKit
import SwiftUI

struct ShuttlXWatchWidgets: WidgetBundle {
    var body: some Widget {
        LastWorkoutComplication()
        WeeklyProgressComplication()
        QuickStartComplication()
    }
}
