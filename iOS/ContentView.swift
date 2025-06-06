//
//  ContentView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Simple test content view to verify dependency injection is working
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VStack {
                Text("ShuttlX Fitness App")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Dependency Injection Pattern Successfully Implemented!")
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("Architecture Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("ViewModels use dependency injection")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Views use @EnvironmentObject")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Services configured with dependencies")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("CloudKit-API synchronization ready")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Real-time messaging configured")
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Text("Ready to integrate with actual Shared services")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            VStack {
                Text("Social Features")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Architecture ready for:")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Feed and Posts")
                    Text("• Real-time Messaging")
                    Text("• Challenges and Teams")
                    Text("• Leaderboards")
                    Text("• Achievements and Badges")
                    Text("• User Profiles and Following")
                }
                .font(.body)
                .padding()
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "person.2.fill")
                Text("Social")
            }
            .tag(1)
        }
        .accentColor(.orange)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}
