import SwiftUI

struct DevicePickerView: View {
    @Binding var selectedDeviceID: UUID?
    @ObservedObject var deviceManager = DeviceManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button {
                    selectedDeviceID = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        Text("No Device")
                        Spacer()
                        if selectedDeviceID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(ShuttlXColor.ctaPrimary)
                        }
                    }
                }
                .accessibilityLabel("No Device")
                .accessibilityValue(selectedDeviceID == nil ? "Selected" : "")
            }

            Section("Devices") {
                ForEach(deviceManager.devices) { device in
                    Button {
                        selectedDeviceID = device.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: device.icon)
                                .font(.title3)
                                .foregroundStyle(device.sportType.themeColor)
                                .frame(width: 32)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(ShuttlXFont.cardTitle)
                                Text("MET \(device.effectiveMET, specifier: "%.1f")")
                                    .font(ShuttlXFont.cardCaption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            Spacer()

                            if selectedDeviceID == device.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(ShuttlXColor.ctaPrimary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(device.name)
                    .accessibilityValue(selectedDeviceID == device.id ? "Selected" : "")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Select Device")
        .navigationBarTitleDisplayMode(.inline)
    }
}
