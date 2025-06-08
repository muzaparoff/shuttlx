//
//  ContentView.swift
//  ShuttlX
//
//  Created by ShuttlX on 6/5/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serviceLocator: ServiceLocator
    
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "figure.run")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                
                Text("ShuttlX")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your Ultimate Training Companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("ShuttlX")
        }
        .onAppear {
            print("📱 ContentView appeared")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ServiceLocator.shared)
    }
}