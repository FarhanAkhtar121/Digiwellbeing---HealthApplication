import SwiftUI
internal import HealthKit

struct DashboardView: View {
    @State private var showWellnessDetail = false
    @StateObject private var wellnessVM = WellnessViewModel()
    let gridItems = [GridItem(.flexible()), GridItem(.flexible())]
    @State private var showHeartMonitor = false
    @State private var showWorkouts = false
    @State private var showStepsDetail = false
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var health = HealthKitManager.shared
    @State private var syncInProgress = false
    @State private var syncError: String? = nil
    @State private var didInitialSync = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    AppTopBar(title: "DigitalWellbeing - Health App", showLogout: true) { authManager.signOut() }
                    
                    // Wellness Score Card
                    NavigationLink(destination: WellnessDetailView(viewModel: wellnessVM)) {
                        WellnessScoreCard(score: wellnessVM.currentScore, trend: wellnessVM.getScoreTrend())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    
                    // Welcome message
                    if let name = authManager.userName {
                        Text("Welcome, \(name)!")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // Mock data indicator
                    if health.useMockData {
                        Label("Showing demo data (Simulator)", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Sync status
                    if syncInProgress {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("Starting live sync…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.padding(.horizontal)
                    } else if let syncError = syncError {
                        Text(syncError)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    // Dashboard title
                    Text("Health Dashboard")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(Color.accentColor)
                        .padding(.top, 4)
                    
                    // Top four cards grid
                    LazyVGrid(columns: gridItems, spacing: 16) {
                        VO2MaxCard(value: health.vo2Max)
                        SleepQualityCard(score: health.sleepScore)
                        BloodOxygenCard(samples: health.bloodOxygenSamples)
                        BloodOxygenValueCard(value: health.spo2Avg)
                    }
                    .padding(.horizontal)
                    
                    // Heart rate, steps, workouts row
                    LazyVGrid(columns: gridItems, spacing: 16) {
                        Button(action: { showHeartMonitor = true }) {
                            HeartRateCard(currentBPM: health.heartRate, data: Array(health.heartRateHistory.suffix(10).map { $0.heartRate }))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { showStepsDetail = true }) {
                            StepsDistanceCard(totalSteps: health.stepCount,
                                              distanceKm: health.distanceTodayMeters / 1000.0,
                                              exerciseMinutes: health.exerciseMinutesToday)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { showWorkouts = true }) {
                            WorkoutsCard(recentWorkouts: health.recentWorkouts)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal)
                    
                    // Health condition cards
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
                .sheet(isPresented: $showStepsDetail) {
                    StepsDetailView()
                }
            }
        }
        // ✅ FIX: Single .task block that does both sync and wellness data load
        .task {
            await startLiveSyncIfNeeded()
            await wellnessVM.loadWellnessData()
        }
    }
    
    private func startLiveSyncIfNeeded() async {
        guard !syncInProgress, !didInitialSync else { return }
        syncInProgress = true
        defer { syncInProgress = false }
        await health.startContinuousSync()
        didInitialSync = true
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
    let currentBPM: Double
    let data: [Double]
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
            Text("\(Int(currentBPM)) BPM")
                .font(.title2)
                .bold()
                .foregroundColor(.red)
            LineChartView(data: data.isEmpty ? [68, 70, 72, 75, 74, 73, 72, 71, 70, 72] : data, lineColor: .red)
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
    let totalSteps: Int
    let distanceKm: Double
    let exerciseMinutes: Int
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
            HStack(spacing: 8) {
                if distanceKm > 0 {
                    Text(String(format: "%.1f km", distanceKm))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                if exerciseMinutes > 0 {
                    Text("• \(exerciseMinutes) min exercise")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
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
    let recentWorkouts: [HKWorkout]
    
    private func workoutIcon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .yoga: return "figure.yoga"
        case .swimming: return "figure.pool.swim"
        case .functionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .hiking: return "figure.hiking"
        case .traditionalStrengthTraining: return "figure.strengthtraining.functional"
        default: return "flame.fill"
        }
    }
    
    private func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycling"
        case .yoga: return "Yoga"
        case .swimming: return "Swim"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .hiking: return "Hike"
        default: return "Workout"
        }
    }
    
    private func durationText(_ duration: TimeInterval) -> String {
        let mins = Int(duration/60)
        return "\(mins) min"
    }
    
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
            if recentWorkouts.isEmpty {
                Text("No recent workouts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(recentWorkouts.prefix(2), id: \.uuid) { w in
                    HStack(spacing: 6) {
                        Image(systemName: workoutIcon(for: w.workoutActivityType))
                            .foregroundColor(.orange)
                        Text(workoutName(for: w.workoutActivityType))
                            .font(.subheadline)
                        Spacer()
                        Text(durationText(w.duration))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
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
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
    private func workoutIcon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .yoga: return "figure.yoga"
        case .swimming: return "figure.pool.swim"
        case .functionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .hiking: return "figure.hiking"
        case .traditionalStrengthTraining: return "figure.strengthtraining.functional"
        default: return "flame.fill"
        }
    }
    
    private func workoutName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycling"
        case .yoga: return "Yoga"
        case .swimming: return "Swim"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .hiking: return "Hike"
        default: return "Workout"
        }
    }
    
    private func durationText(_ duration: TimeInterval) -> String {
        let mins = Int(duration/60)
        return "\(mins) min"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppTopBar(title: "DigitalWellbeing - Health App", showLogout: true) { authManager.signOut() }
                List(health.recentWorkouts, id: \.uuid) { workout in
                    HStack {
                        Image(systemName: workoutIcon(for: workout.workoutActivityType))
                            .foregroundColor(.orange)
                            .frame(width: 32)
                        VStack(alignment: .leading) {
                            Text(workoutName(for: workout.workoutActivityType))
                                .font(.headline)
                            Text(workout.endDate, style: .time)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(durationText(workout.duration))
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Chart Components

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

// MARK: - Calendar Component

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

// MARK: - Preview (Disabled for now since singletons can't initialize without app context)

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview disabled - DashboardView requires initialized singletons
        // (AuthManager, HealthKitManager) which can't be created in preview context
        Text("DashboardView Preview requires running app context")
    }
}
