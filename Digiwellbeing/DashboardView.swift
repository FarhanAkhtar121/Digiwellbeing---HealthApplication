import SwiftUI

struct DashboardView: View {
    let gridItems = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var showHeartMonitor = false
    @State private var showWorkouts = false
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var health = HealthKitManager.shared
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = authManager.userName {
                                Text("Welcome, \(name)!")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.accentColor)
                            }
                        }
                        Spacer()
                        Button(action: {
                            authManager.signOut()
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title2)
                                .foregroundColor(.red)
                                .accessibilityLabel("Logout")
                        }
                    }
                    .padding([.top, .horizontal])

                    if health.useMockData {
                        Label("Showing demo data (Simulator)", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }

                    Text("Health Dashboard")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(Color.accentColor)
                        .padding(.top, 4)
                    // 2x2 grid for top four cards
                    LazyVGrid(columns: gridItems, spacing: 16) {
                        VO2MaxCard(value: health.vo2Max)
                        SleepQualityCard(score: health.sleepScore)
                        BloodOxygenCard(samples: health.bloodOxygenSamples)
                        BloodOxygenValueCard(value: health.spo2Avg)
                    }
                    .padding(.horizontal)
                    // New row for heart rate, steps, workouts
                    LazyVGrid(columns: gridItems, spacing: 16) {
                        Button(action: { showHeartMonitor = true }) {
                            HeartRateCard()
                        }
                        .buttonStyle(PlainButtonStyle())
                        StepsDistanceCard()
                        Button(action: { showWorkouts = true }) {
                            WorkoutsCard()
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal)
                    // Main cards
                    VStack(spacing: 16) {
                        MenstrualCycleCard()
                        HypertensionAlertCard()
                        SleepApneaCard()
                        NoiseLevelCard()
                    }
                    .padding(.horizontal)
                }
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemTeal).opacity(0.08)]), startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
                .navigationBarHidden(true)
                .sheet(isPresented: $showHeartMonitor) {
                    HeartMonitorView()
                }
                .sheet(isPresented: $showWorkouts) {
                    WorkoutsDetailView()
                }
            }
        }
        .task {
            _ = try? await health.requestAuthorization()
        }
    }
}

// MARK: - Card Components

struct VO2MaxCard: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VO2 Max")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(value.map { String(format: "%.1f mL/kg/min", $0) } ?? "—")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            LineChartView(data: [40, 42, 44, 45, 43, 45, 46, 45, 44, 45], lineColor: .white)
                .frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.purple.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct SleepQualityCard: View {
    let score: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Quality")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(score.map { "\($0)%" } ?? "—")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            LineChartView(data: [70, 75, 80, 85, 90, 85, 80, 85, 88, 85], lineColor: .white)
                .frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.teal, Color.green]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.teal.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct BloodOxygenCard: View {
    let samples: [Double]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blood Oxygen")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            LineChartView(data: samples.isEmpty ? [97, 98, 97, 99, 98, 97, 98] : samples, lineColor: .white)
                .frame(height: 32)
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.blue.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct BloodOxygenValueCard: View {
    let value: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Blood Oxygen")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.white)
                Text(value.map { String(format: "%.0f%%", $0) } ?? "—")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.indigo, Color.mint]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.indigo.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct MenstrualCycleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Menstrual Cycle:")
                    .font(.headline)
                Spacer()
                Text("Day 14")
                    .font(.subheadline)
            }
            CalendarView(selectedDay: 19)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct HypertensionAlertCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Hypertension Alert:")
                    .font(.headline)
                Text("140/90 mmHg")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.red)
            }
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.title)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct SleepApneaCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Sleep Apnea")
                    .font(.headline)
                Text("Notification: 3 events/hr")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "mic.fill")
                .foregroundColor(.gray)
                .font(.title)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct NoiseLevelCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Noise Level")
                .font(.headline)
            Text("45 dB")
                .font(.title2)
                .bold()
            ColorfulBarChartView(data: [30, 35, 40, 45, 50, 45, 40, 35, 30, 45, 50, 45, 40, 35, 30])
                .frame(height: 40)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

// MARK: - New Cards

struct HeartRateCard: View {
    let avgHeartRate = 72
    let heartRateData: [Double] = [68, 70, 72, 75, 74, 73, 72, 71, 70, 72]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart Rate")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            Spacer()
            Text("\(avgHeartRate) BPM")
                .font(.title2)
                .bold()
                .foregroundColor(.red)
            LineChartView(data: heartRateData, lineColor: .red)
                .frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.8), Color.pink.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.red.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct StepsDistanceCard: View {
    let totalSteps = 8500
    let distance = 6.2 // km
    let stepsData: [Double] = [200, 500, 800, 1200, 1500, 2000, 1800, 1600, 1200, 800, 400, 200]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.blue)
                Text("Steps & Distance")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            Spacer()
            Text("\(totalSteps) steps")
                .font(.title2)
                .bold()
                .foregroundColor(.blue)
            Text(String(format: "%.1f km", distance))
                .font(.subheadline)
                .foregroundColor(.blue)
            ColorfulBarChartView(data: stepsData)
                .frame(height: 32)
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.blue.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct WorkoutsCard: View {
    let recentWorkouts = [
        ("Bicycle", "bicycle", "30 min"),
        ("Run", "figure.run", "20 min"),
        ("Yoga", "figure.yoga", "45 min")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Workouts")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            Spacer()
            ForEach(recentWorkouts.prefix(2), id: \.0) { workout in
                HStack(spacing: 6) {
                    Image(systemName: workout.1)
                        .foregroundColor(.orange)
                    Text(workout.0)
                        .font(.subheadline)
                    Spacer()
                    Text(workout.2)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            HStack {
                Spacer()
                Text("See all")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .frame(height: 120)
        .background(LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.yellow.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(18)
        .shadow(color: Color.orange.opacity(0.15), radius: 6, x: 0, y: 4)
    }
}

struct WorkoutsDetailView: View {
    let workouts = [
        ("Bicycle", "bicycle", "30 min", "Morning ride"),
        ("Run", "figure.run", "20 min", "Park run"),
        ("Yoga", "figure.yoga", "45 min", "Evening yoga"),
        ("HIIT", "figure.strengthtraining.traditional", "25 min", "HIIT session")
    ]
    var body: some View {
        NavigationView {
            List(workouts, id: \.0) { workout in
                HStack {
                    Image(systemName: workout.1)
                        .foregroundColor(.orange)
                        .frame(width: 32)
                    VStack(alignment: .leading) {
                        Text(workout.0)
                            .font(.headline)
                        Text(workout.3)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(workout.2)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Chart Placeholders

struct LineChartView: View {
    let data: [Double]
    var lineColor: Color = .blue
    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard data.count > 1 else { return }
                let width = geo.size.width
                let height = geo.size.height
                let maxY = data.max() ?? 1
                let minY = data.min() ?? 0
                let yRange = maxY - minY == 0 ? 1 : maxY - minY
                let stepX = width / CGFloat(data.count - 1)
                for (i, value) in data.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = height - ((CGFloat(value - minY) / CGFloat(yRange)) * height)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(lineColor, lineWidth: 2)
        }
    }
}

struct ColorfulBarChartView: View {
    let data: [Double]
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width / CGFloat(data.count)
            let maxY = data.max() ?? 1
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<data.count, id: \.self) { i in
                    Rectangle()
                        .fill(barColor(for: data[i], max: maxY))
                        .frame(width: width - 2, height: CGFloat(data[i]) / CGFloat(maxY) * geo.size.height)
                }
            }
        }
    }
    func barColor(for value: Double, max: Double) -> LinearGradient {
        let percent = value / max
        if percent > 0.8 {
            return LinearGradient(gradient: Gradient(colors: [Color.red, Color.orange]), startPoint: .bottom, endPoint: .top)
        } else if percent > 0.6 {
            return LinearGradient(gradient: Gradient(colors: [Color.orange, Color.yellow]), startPoint: .bottom, endPoint: .top)
        } else if percent > 0.4 {
            return LinearGradient(gradient: Gradient(colors: [Color.yellow, Color.green]), startPoint: .bottom, endPoint: .top)
        } else {
            return LinearGradient(gradient: Gradient(colors: [Color.green, Color.teal]), startPoint: .bottom, endPoint: .top)
        }
    }
}

// MARK: - Simple Calendar Placeholder

struct CalendarView: View {
    let selectedDay: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(13...22, id: \.self) { day in
                Text("\(day)")
                    .font(.subheadline)
                    .frame(width: 28, height: 28)
                    .background(day == selectedDay ? Color.red.opacity(0.2) : Color.clear)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
