import SwiftUI

struct DeviceListView: View {
    @Environment(ThemeManager.self) var themeManager
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingAddDevice = false
    @State private var editingDevice: ExerciseDevice?

    var body: some View {
        List {
            Section("Built-in Devices") {
                ForEach(deviceManager.devices.filter { $0.isBuiltIn }) { device in
                    DeviceRow(device: device)
                        .onTapGesture { editingDevice = device }
                }
            }

            if !customDevices.isEmpty {
                Section("Custom Devices") {
                    ForEach(customDevices) { device in
                        DeviceRow(device: device)
                            .onTapGesture { editingDevice = device }
                    }
                    .onDelete(perform: deleteCustomDevice)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .navigationTitle("Exercise Devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddDevice = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add custom device")
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            DeviceEditorView(mode: .add)
        }
        .sheet(item: $editingDevice) { device in
            DeviceEditorView(mode: .edit(device))
        }
        .themedScreenBackground()
    }

    private var customDevices: [ExerciseDevice] {
        deviceManager.devices.filter { !$0.isBuiltIn }
    }

    private func deleteCustomDevice(at offsets: IndexSet) {
        for index in offsets {
            let device = customDevices[index]
            deviceManager.deleteDevice(device)
        }
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: ExerciseDevice

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.icon)
                .font(.title3)
                .foregroundStyle(device.sportType.themeColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(ShuttlXFont.cardTitle)
                HStack(spacing: 8) {
                    Text(device.category.displayName)
                    Text("MET \(device.effectiveMET, specifier: "%.1f")")
                        .monospacedDigit()
                }
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if device.customMET != nil {
                Text("Custom")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ShuttlXColor.ctaPrimary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.name), \(device.category.displayName)")
        .accessibilityValue("MET \(device.effectiveMET, specifier: "%.1f")")
    }
}

// MARK: - Device Editor

private struct DeviceEditorView: View {
    enum Mode: Identifiable {
        case add
        case edit(ExerciseDevice)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let device): return device.id.uuidString
            }
        }
    }

    let mode: Mode
    @ObservedObject var deviceManager = DeviceManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: DeviceCategory = .custom
    @State private var sportType: WorkoutSport = .crossTraining
    @State private var metValue: String = "5.0"
    @State private var icon: String = "figure.mixed.cardio"

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingDevice: ExerciseDevice? {
        if case .edit(let device) = mode { return device }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Info") {
                    if let device = existingDevice, device.isBuiltIn {
                        Text(device.name)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Device Name", text: $name)
                    }

                    if existingDevice?.isBuiltIn != true {
                        Picker("Category", selection: $category) {
                            ForEach(DeviceCategory.allCases) { cat in
                                Text(cat.displayName).tag(cat)
                            }
                        }

                        Picker("Sport Type", selection: $sportType) {
                            ForEach(WorkoutSport.allCases) { sport in
                                Label(sport.displayName, systemImage: sport.systemImage)
                                    .tag(sport)
                            }
                        }
                    }
                }

                Section("MET Value") {
                    HStack {
                        TextField("MET", text: $metValue)
                            .keyboardType(.decimalPad)
                        if let device = existingDevice {
                            Text("Default: \(device.defaultMET, specifier: "%.1f")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("MET (Metabolic Equivalent) measures exercise intensity. Higher values = more calories burned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEdit ? "Edit Device" : "Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty && existingDevice?.isBuiltIn != true)
                }
            }
            .onAppear { populateFields() }
        }
    }

    private func populateFields() {
        guard let device = existingDevice else { return }
        name = device.name
        category = device.category
        sportType = device.sportType
        metValue = String(format: "%.1f", device.customMET ?? device.defaultMET)
        icon = device.icon
    }

    private func save() {
        let met = Double(metValue) ?? 5.0

        if let existing = existingDevice {
            var updated = existing
            if !existing.isBuiltIn {
                updated.name = name
                updated.category = category
                updated.sportType = sportType
                updated.icon = category.defaultIcon
            }
            // Allow customMET on any device (including built-in)
            updated.customMET = (met != existing.defaultMET) ? met : nil
            deviceManager.updateDevice(updated)
        } else {
            let device = ExerciseDevice(
                name: name,
                category: category,
                sportType: sportType,
                defaultMET: met,
                icon: category.defaultIcon
            )
            deviceManager.addDevice(device)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        DeviceListView()
            .environment(ThemeManager.shared)
    }
}
