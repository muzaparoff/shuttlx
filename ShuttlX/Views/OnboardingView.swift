import SwiftUI
import HealthKit

struct OnboardingView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var isFirstLaunch: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Welcome page
                VStack(spacing: 20) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Welcome to ShuttlX")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your personal training assistant for running, cycling, and more")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        currentPage = 1
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .tag(0)
                
                // HealthKit permissions page
                VStack(spacing: 20) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    
                    Text("Health Integration")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("ShuttlX uses HealthKit to read and store your workout data to provide personalized training insights.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "heart.circle")
                                .font(.title)
                            Text("Heart Rate")
                                .font(.caption)
                        }
                        
                        VStack {
                            Image(systemName: "flame.circle")
                                .font(.title)
                            Text("Calories")
                                .font(.caption)
                        }
                        
                        VStack {
                            Image(systemName: "figure.walk.circle")
                                .font(.title)
                            Text("Steps & Distance")
                                .font(.caption)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await dataManager.requestHealthKitPermissions()
                            isFirstLaunch = false
                        }
                    } label: {
                        Text("Grant Health Access")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        isFirstLaunch = false
                    } label: {
                        Text("Skip for Now")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                }
                .padding()
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isFirstLaunch: .constant(true))
            .environmentObject(DataManager())
    }
}
