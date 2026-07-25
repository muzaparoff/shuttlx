import AppIntents

/// Configuration intent for W1 (Start Training). The widget itself never
/// runs this intent's `perform()` — `AppIntentConfiguration` only uses it to
/// drive the "Edit Widget" picker UI. Starting the workout happens by
/// deep-linking into the host app via `.widgetURL` (the widget process can't
/// reach `PhoneSyncCoordinator` / WatchConnectivity — see proposal open
/// question #1).
struct StartTrainingConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Start Training"
    static var description = IntentDescription("Choose a workout template to start with one tap from your Home Screen.")

    @Parameter(title: "Template")
    var template: WorkoutTemplateEntity?
}
