import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: SimpleDataManager
    
    var body: some View {
        TabView {
            // Simple program list
            NavigationView {
                List(dataManager.programs, id: \.self) { program in
                    Text(program)
                }
                .navigationTitle("Training Programs")
            }
            .tabItem {
                Label("Programs", systemImage: "list.bullet")
            }
            
            // Simple training history
            NavigationView {
                Text("Training History")
                    .navigationTitle("History")
            }
            .tabItem {
                Label("History", systemImage: "calendar")
            }
        }
    }
}
