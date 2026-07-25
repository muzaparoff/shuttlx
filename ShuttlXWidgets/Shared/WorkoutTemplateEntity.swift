import AppIntents

/// `AppEntity` wrapper around `WorkoutTemplate` for W1's `AppIntentConfiguration`
/// picker. Snapshotted (name/summary/icon) at query time rather than holding
/// a live `WorkoutTemplate` reference — the widget re-resolves the full
/// template from disk by `id` on every timeline build (see
/// `StartTrainingProvider`), so a stale snapshot here only affects the
/// configuration UI's list labels, never the actual start behavior.
struct WorkoutTemplateEntity: AppEntity {
    let id: UUID
    let name: String
    let summaryText: String
    let sportIcon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workout Template"
    static var defaultQuery = TemplateEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summaryText)")
    }
}

struct TemplateEntityQuery: EntityQuery {
    func entities(for identifiers: [WorkoutTemplateEntity.ID]) async throws -> [WorkoutTemplateEntity] {
        Self.allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WorkoutTemplateEntity] {
        Self.allEntities()
    }

    func defaultResult() async -> WorkoutTemplateEntity? {
        Self.allEntities().first
    }

    private static func allEntities() -> [WorkoutTemplateEntity] {
        WidgetTemplateProvider.loadTemplates().map { template in
            WorkoutTemplateEntity(
                id: template.id,
                name: template.name,
                summaryText: template.summaryText,
                sportIcon: template.sportType?.systemImage ?? "figure.run"
            )
        }
    }
}
