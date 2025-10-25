//
//  ContentView.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 18/09/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthManager = HealthKitManager.shared
    @StateObject private var connectivityManager = ConnectivityManager.shared
    
    @State private var heartRateHistory: [HeartRateReading] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Heart Rate Card
                    HeartRateCard(heartRate: healthManager.heartRate)
                    
                    // Heart Rate History Chart
                    HeartRateChartView(readings: heartRateHistory)
                    
                    // Control Buttons
                    HStack(spacing: 20) {
                        Button("Start Monitoring") {
                            healthManager.startHeartRateMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Request Permission") {
                            Task {
                                do {
                                    let authorized = try await healthManager.requestAuthorization()
                                    healthManager.isAuthorized = authorized
                                } catch {
                                    print("Authorization failed: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Heart Monitor")
            .onAppear {
                Task {
                    do {
                        let authorized = try await healthManager.requestAuthorization()
                        healthManager.isAuthorized = authorized
                    } catch {
                        print("Authorization failed: \(error)")
                    }
                }
            }
            .onChange(of: connectivityManager.heartRateData) { _, newData in
                if let heartRate = newData["heartRate"] as? Double,
                   let timestamp = newData["timestamp"] as? TimeInterval {
                    let reading = HeartRateReading(
                        heartRate: heartRate,
                        timestamp: Date(timeIntervalSince1970: timestamp)
                    )
                    heartRateHistory.append(reading)
                }
            }
        }
    }
}

struct HeartRateCard: View {
    let heartRate: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.red.gradient)
            .frame(height: 150)
            .overlay {
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    Text("\(Int(heartRate))")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("BPM")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)
    }
}

struct HeartRateReading: Identifiable {
    let id = UUID()
    let heartRate: Double
    let timestamp: Date
}

