import SwiftUI
import HealthKit
import Charts

struct SignInView: View {
    @ObservedObject private var authManager = AuthManager.shared
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Sign In")
                .font(.largeTitle)
                .padding(.top, 40)
            Button(action: {
                authManager.signInWithGoogle()
            }) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            Button(action: {
                authManager.signInWithMicrosoft()
            }) {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text("Sign in with Microsoft")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

struct ContentView: View {
    @ObservedObject private var authManager = AuthManager.shared
    
    var body: some View {
        if authManager.isAuthenticated {
            HomeTabsView()
        } else {
            SignInView()
        }
    }
}

struct HomeTabsView: View {
    @ObservedObject private var authManager = AuthManager.shared
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "heart.text.square")
                }
            SharingView()
                .tabItem {
                    Label("Sharing", systemImage: "person.2.fill")
                }
        }
        .tint(.accentColor)
    }
}

struct HeartMonitorView: View {
    @ObservedObject private var healthKitManager = HealthKitManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        VStack {
            HStack {
                if let name = authManager.userName {
                    Text("Welcome, \(name)!")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Button {
                    authManager.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                        .font(.title3)
                        .accessibilityLabel("Logout")
                }
            }
            .padding([.top, .horizontal])

            Text("Heart Monitor")
                .font(.largeTitle)
                .padding()

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.2))
                .frame(height: 100)
                .overlay {
                    VStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title)
                        Text("\(Int(healthKitManager.heartRate)) BPM")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
                .padding()

            HeartRateChartView(readings: healthKitManager.heartRateHistory)

            HStack {
                Button("Start Monitoring") {
                    healthKitManager.startHeartRateMonitoring()
                }
                .buttonStyle(.bordered)

                Button("Request Permission") {
                    Task {
                        do {
                            let success = try await healthKitManager.requestAuthorization()
                            healthKitManager.isAuthorized = success
                        } catch {
                            print("Authorization failed: \(error.localizedDescription)")
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .onAppear {
            Task {
                do {
                    let success = try await healthKitManager.requestAuthorization()
                    healthKitManager.isAuthorized = success
                } catch {
                    print("Authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
