import AppIntents

/// Hook the host app sets at launch (`ShuttlXApp.init`). The Live Activity buttons
/// compile these intents into the extension too, but iOS runs `perform()` in the
/// app process — the extension never touches WatchConnectivity.
enum WorkoutControlBridge {
    @MainActor static var send: ((String) -> Void)?
    /// Set by the app once the phone workout controller exists; true when it handled the command.
    @MainActor static var phoneWorkout: ((String) -> Bool)?
}

struct PauseResumeWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Workout"
    static var isDiscoverable: Bool { false }   // Live Activity buttons only: not offered in Shortcuts or Spotlight
    @Parameter(title: "Resume") var resume: Bool

    init() {}
    init(resume: Bool) { self.resume = resume }

    @MainActor func perform() async throws -> some IntentResult {
        WorkoutControlBridge.send?(resume ? "resume" : "pause")
        return .result()
    }
}

struct EndWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Workout"
    static var isDiscoverable: Bool { false }
    init() {}

    @MainActor func perform() async throws -> some IntentResult {
        WorkoutControlBridge.send?("stop")
        return .result()
    }
}
