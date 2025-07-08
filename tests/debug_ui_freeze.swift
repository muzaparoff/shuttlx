import SwiftUI

/**
 * debug_ui_freeze.swift
 * Diagnostic tool to help isolate navigation freezes in the iOS app
 *
 * How to use:
 * 1. Replace ContentView in ShuttlXApp.swift temporarily with FreezeTestView
 * 2. Run the app and test various navigation patterns
 * 3. Monitor console output for logs showing potential deadlocks
 *
 * This test view isolates UI navigation from data operations to help
 * pinpoint where freezes are occurring.
 */

struct FreezeTestView: View {
    @StateObject private var dataManager = DataManager()
    @State private var selection = 0
    @State private var isShowingSheet = false
    
    var body: some View {
        TabView(selection: $selection) {
            // Tab 1: Simple navigation test
            VStack(spacing: 20) {
                Text("Navigation Freeze Test")
                    .font(.title)
                
                Button("Load Data") {
                    print("🔍 TEST: Manually triggering data load")
                    dataManager.loadProgramsFromAppGroup()
                }
                
                Button("Show Sheet") {
                    print("🔍 TEST: Opening sheet")
                    isShowingSheet = true
                }
                
                Button("Go to Tab 2") {
                    print("🔍 TEST: Switching to Tab 2")
                    selection = 1
                }
            }
            .tabItem {
                Image(systemName: "1.circle")
                Text("Test 1")
            }
            .tag(0)
            .onAppear {
                print("🔍 TEST: Tab 1 appeared")
            }
            
            // Tab 2: Data loading test
            VStack(spacing: 20) {
                Text("Data Operations Test")
                    .font(.title)
                
                Button("Sync to Watch") {
                    print("🔍 TEST: Manually triggering watch sync")
                    Task {
                        print("🔍 TEST: Starting sync task")
                        await testSyncOperation()
                        print("🔍 TEST: Sync task completed")
                    }
                }
                
                Button("Go to Tab 1") {
                    print("🔍 TEST: Switching to Tab 1")
                    selection = 0
                }
            }
            .tabItem {
                Image(systemName: "2.circle")
                Text("Test 2")
            }
            .tag(1)
            .onAppear {
                print("🔍 TEST: Tab 2 appeared")
            }
        }
        .sheet(isPresented: $isShowingSheet) {
            VStack {
                Text("Test Sheet")
                    .font(.title)
                
                Button("Close") {
                    isShowingSheet = false
                }
            }
            .onAppear {
                print("🔍 TEST: Sheet appeared")
            }
            .onDisappear {
                print("🔍 TEST: Sheet disappeared")
            }
        }
        .onAppear {
            print("🔍 TEST: FreezeTestView appeared")
            
            // Start timer to log UI responsiveness
            startResponsivenessMonitor()
        }
    }
    
    // Simulates the sync operation without actually changing data
    func testSyncOperation() async {
        print("🔍 TEST: Getting SharedDataManager")
        let manager = SharedDataManager.shared
        
        print("🔍 TEST: About to call MainActor method")
        await MainActor.run {
            print("🔍 TEST: Inside MainActor block")
            manager.log("Test sync operation started")
        }
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        print("🔍 TEST: Sleep completed, returning to MainActor")
        await MainActor.run {
            print("🔍 TEST: Inside second MainActor block")
            manager.log("Test sync operation completed")
        }
        
        print("🔍 TEST: testSyncOperation completed")
    }
    
    // Monitors UI thread responsiveness
    func startResponsivenessMonitor() {
        var counter = 0
        
        // Create a timer that increments a counter every 0.5 seconds
        // If UI is frozen, these prints will stop appearing in the console
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            counter += 1
            print("⏱️ UI responsiveness check: \(counter)")
            
            // Stop after 60 seconds (120 checks)
            if counter >= 120 {
                timer.invalidate()
                print("⏱️ UI responsiveness monitor stopped after 60 seconds")
            }
        }
    }
}
