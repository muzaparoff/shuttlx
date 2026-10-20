import AppIntents

/// Hook the host app sets at launch (`ShuttlXApp.init`). The Live Activity buttons
/// compile these intents into the extension too, but iOS runs `perform()` in the
/// app process — the extension never touches WatchConnectivity.
enum WorkoutControlBridge {
    @MainActor static var send: ((String) -> Void)?
}

struct PauseResumeWorkoutIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Workout"
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
    init() {}

    @MainActor func perform() async throws -> some IntentResult {
        WorkoutControlBridge.send?("stop")
        return .result()
    }
}
