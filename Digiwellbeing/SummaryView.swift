import SwiftUI

struct SummaryView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var health = HealthKitManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppTopBar(title: "DigitalWellbeing - Health App", showLogout: true) { authManager.signOut() }
                    if let name = authManager.userName {
                        Text("Welcome, \(name)!")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal)
                    }

                    Text("Summary")
                        .font(.largeTitle)
                        .bold()
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        SummaryActivityCard()
                        SummaryStepsCard()
                        SummaryVO2MaxCard(value: health.vo2Max)
                        SummarySpO2Card(avg: health.spo2Avg, samples: health.bloodOxygenSamples)
                        SummaryWalkingSteadinessCard()
                        SummarySleepScoreCard(score: health.sleepScore)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemPink).opacity(0.08)]), startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Summary Cards

struct SummaryCard: View {
    let title: String
    let icon: String
    let tint: Color
    let content: () -> AnyView

    init(title: String, icon: String, tint: Color, @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(tint)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

struct SummaryActivityCard: View {
    var body: some View {
        SummaryCard(title: "Activity", icon: "flame.fill", tint: .orange) {
            HStack {
                VStack(alignment: .leading) {
                    Text("223 cal").font(.title3).bold()
                    Text("Move").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("17 min").font(.title3).bold()
                    Text("Exercise").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("3 hr").font(.title3).bold()
                    Text("Stand").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chart.pie.fill").foregroundColor(.orange)
            }
        }
    }
}

struct SummaryStepsCard: View {
    @ObservedObject private var health = HealthKitManager.shared
    var body: some View {
        SummaryCard(title: "Steps", icon: "figure.walk", tint: .blue) {
            VStack(alignment: .leading) {
                Text("\(health.stepCount) steps").font(.title2).bold()
                ColorfulBarChartView(data: [200, 600, 1200, 800, 400, 1400, 900]).frame(height: 48)
            }
        }
    }
}

struct SummaryVO2MaxCard: View {
    let value: Double?
    var body: some View {
        SummaryCard(title: "VO2 Max", icon: "lungs.fill", tint: .purple) {
            HStack {
                Text(value.map { String(format: "%.1f mL/kg/min", $0) } ?? "—")
                    .font(.title3)
                    .bold()
                Spacer()
                Image(systemName: "waveform").foregroundColor(.purple)
            }
        }
    }
}

struct SummarySpO2Card: View {
    let avg: Double?
    let samples: [Double]
    var body: some View {
        SummaryCard(title: "Blood Oxygen", icon: "drop.fill", tint: .teal) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(avg.map { String(format: "%.0f%%", $0) } ?? "—")
                        .font(.title3)
                        .bold()
                    Spacer()
                }
                ColorfulBarChartView(data: samples.isEmpty ? [97, 98, 97, 99, 98, 97, 98] : samples)
                    .frame(height: 32)
            }
        }
    }
}

struct SummaryWalkingSteadinessCard: View {
    var body: some View {
        SummaryCard(title: "Walking Steadiness", icon: "figure.walk.motion", tint: .orange) {
            HStack {
                VStack(alignment: .leading) {
                    Text("OK").font(.title3).bold()
                    Text("Mar 20–27").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.orange.opacity(0.3), .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 80, height: 24)
            }
        }
    }
}

struct SummarySleepScoreCard: View {
    let score: Int?
    var body: some View {
        SummaryCard(title: "Sleep Score", icon: "bed.double.fill", tint: .purple) {
            HStack {
                VStack(alignment: .leading) {
                    Text(score.map { $0 >= 85 ? "Excellent" : ($0 >= 70 ? "Good" : "Fair") } ?? "—")
                        .font(.title3)
                        .bold()
                    Text(score.map { "\($0) points" } ?? "No data").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    let progress = Double(score ?? 0) / 100.0
                    Circle().trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .foregroundColor(.blue)
                    Text(score.map { "\($0)" } ?? "—").bold()
                }
                .frame(width: 44, height: 44)
            }
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}
