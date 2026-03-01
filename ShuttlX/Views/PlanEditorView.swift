import SwiftUI

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var templateManager: TemplateManager

    @State private var name: String = ""
    @State private var planDescription: String = ""
    @State private var sportType: WorkoutSport = .running
    @State private var weeks: [PlanWeek] = [PlanWeek(weekNumber: 1, days: (1...7).map { PlanDay(dayNumber: $0) })]

    private let onSave: (TrainingPlan) -> Void

    init(onSave: @escaping (TrainingPlan) -> Void) {
        self.onSave = onSave
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Plan Name", text: $name)
                        .accessibilityLabel("Plan name")
                    TextField("Description (optional)", text: $planDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Plan description, optional")
                } header: {
                    Text("Details")
                }

                Section {
                    Picker("Sport", selection: $sportType) {
                        ForEach(WorkoutSport.allCases) { sport in
                            Label(sport.displayName, systemImage: sport.systemImage)
                                .tag(sport)
                        }
                    }
                    .accessibilityLabel("Sport type")
                } header: {
                    Text("Sport Type")
                }

                ForEach($weeks) { $week in
                    Section {
                        ForEach($week.days) { $day in
                            dayEditor(day: $day)
                        }
                    } header: {
                        HStack {
                            Text("Week \(week.weekNumber)")
                            Spacer()
                            if weeks.count > 1 {
                                Button("Remove") {
                                    weeks.removeAll { $0.id == week.id }
                                    renumberWeeks()
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Remove week \(week.weekNumber)")
                            }
                        }
                    }
                }

                Section {
                    Button(action: addWeek) {
                        Label("Add Week", systemImage: "plus.circle")
                    }
                    .accessibilityLabel("Add another week")
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePlan() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func dayEditor(day: Binding<PlanDay>) -> some View {
        HStack {
            Text(dayLabel(day.wrappedValue.dayNumber))
                .font(.caption.weight(.semibold))
                .frame(width: 30)
                .foregroundStyle(.secondary)

            if day.wrappedValue.isRestDay {
                Text("Rest Day")
                    .foregroundStyle(.secondary)
                    .italic()
                Spacer()
                Button("Add Workout") {
                    day.wrappedValue.templateName = "Workout"
                    day.wrappedValue.templateID = nil
                }
                .font(.caption)
                .accessibilityLabel("Add workout on \(dayLabel(day.wrappedValue.dayNumber))")
            } else {
                TextField("Workout name", text: Binding(
                    get: { day.wrappedValue.templateName ?? "" },
                    set: { day.wrappedValue.templateName = $0.isEmpty ? nil : $0 }
                ))
                .font(.subheadline)
                .accessibilityLabel("Workout name for \(dayLabel(day.wrappedValue.dayNumber))")

                Button(action: {
                    day.wrappedValue.templateName = nil
                    day.wrappedValue.templateID = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove workout from \(dayLabel(day.wrappedValue.dayNumber))")
            }
        }
    }

    private func dayLabel(_ number: Int) -> String {
        switch number {
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        case 7: return "Sun"
        default: return "D\(number)"
        }
    }

    private func addWeek() {
        let newWeekNumber = weeks.count + 1
        let newWeek = PlanWeek(weekNumber: newWeekNumber, days: (1...7).map { PlanDay(dayNumber: $0) })
        weeks.append(newWeek)
    }

    private func renumberWeeks() {
        for i in weeks.indices {
            weeks[i].weekNumber = i + 1
        }
    }

    private func savePlan() {
        let plan = TrainingPlan(
            name: name.trimmingCharacters(in: .whitespaces),
            planDescription: planDescription.isEmpty ? nil : planDescription,
            sportType: sportType,
            weeks: weeks
        )
        onSave(plan)
        dismiss()
    }
}

#Preview {
    PlanEditorView { _ in }
        .environmentObject(TemplateManager())
}
