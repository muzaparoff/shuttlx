import SwiftUI
import HealthKit

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingHealthPermissionsInfo = false
    
    var body: some View {
        List {
            Section(header: Text("Health Integration")) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("HealthKit Status")
                    Spacer()
                    Text(dataManager.healthKitAuthorized ? "Connected" : "Not Connected")
                        .foregroundColor(dataManager.healthKitAuthorized ? .green : .red)
                }
                
                if !dataManager.healthKitAuthorized {
                    Button("Request HealthKit Access") {
                        Task {
                            await dataManager.requestHealthKitPermissions()
                        }
                    }
                    
                    Button("Why We Need Access") {
                        showingHealthPermissionsInfo = true
                    }
                }
            }
            
            Section(header: Text("Sync")) {
                Button("Force Sync with Watch") {
                    if let programs = dataManager.programs as? [TrainingProgram] {
                        SharedDataManager.shared.syncProgramsToWatch(programs)
                    }
                }
                
                Button("Show Debug View") {
                    // Implementation for debug view
                }
            }
            
            Section(header: Text("About")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("101")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
        .sheet(isPresented: $showingHealthPermissionsInfo) {
            HealthPermissionsInfoView()
        }
    }
}

struct HealthPermissionsInfoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Why ShuttlX Needs HealthKit Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Read")
                            .font(.headline)
                        
                        Text("• Heart Rate: To monitor your exertion during workouts")
                        Text("• Steps & Distance: To track your activity accurately")
                        Text("• Calories: To measure energy expenditure")
                    }
                    .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data We Store")
                            .font(.headline)
                        
                        Text("• Workout Sessions: To maintain your training history")
                        Text("• Active Energy: To track calories burned during activities")
                        Text("• Distance: To record your training progress")
                    }
                    .padding(.bottom)
                    
                    Text("Your health data remains private and is only used within the app to enhance your training experience. We never share your health information with third parties.")
                        .italic()
                        .padding(.bottom)
                }
                .padding()
            }
            .navigationBarTitle("Health Permissions", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                // Dismiss sheet
            })
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(DataManager())
        }
    }
}
