---
globs:
  - "**/Models/**"
---

# Model Rules

## Dual-Target Sync

Models are **duplicated** between iOS (`ShuttlX/Models/`) and watchOS (`ShuttlX Watch App/Models/`). When modifying any model:

1. Make the change in BOTH copies
2. Verify both build: `bash tests/build_and_test_both_platforms.sh --clean --build`
3. Keep files identical — do not let them diverge

## Shared Models

| Model | iOS Path | watchOS Path |
|-------|----------|-------------|
| ActivitySegment | `ShuttlX/Models/ActivitySegment.swift` | `ShuttlX Watch App/Models/ActivitySegment.swift` |
| BuiltInPlans | `ShuttlX/Models/BuiltInPlans.swift` | `ShuttlX Watch App/Models/BuiltInPlans.swift` |
| RoutePoint | `ShuttlX/Models/RoutePoint.swift` | `ShuttlX Watch App/Models/RoutePoint.swift` |
| TrainingPlan | `ShuttlX/Models/TrainingPlan.swift` | `ShuttlX Watch App/Models/TrainingPlan.swift` |
| TrainingSession | `ShuttlX/Models/TrainingSession.swift` | `ShuttlX Watch App/Models/TrainingSession.swift` |
| WorkoutSport | `ShuttlX/Models/WorkoutSport.swift` | `ShuttlX Watch App/Models/WorkoutSport.swift` |
| WorkoutTemplate | `ShuttlX/Models/WorkoutTemplate.swift` | `ShuttlX Watch App/Models/WorkoutTemplate.swift` |
| ExerciseDevice | `ShuttlX/Models/ExerciseDevice.swift` | `ShuttlX Watch App/Models/ExerciseDevice.swift` |

## iOS-Only Models

- `ChartData.swift` — chart helpers (iOS analytics only)
- `WorkoutActivityAttributes.swift` — Live Activity attributes

## Conventions

- All models must be `Codable` and `Identifiable`
- Use `UUID` for identity
- Enums must have `String` raw values for stable JSON encoding
- New properties must have default values (backward-compatible decoding)
- Use `CodingKeys` when property names differ from JSON keys
