import Foundation
internal import HealthKit
internal import Combine
internal import Auth
internal import CoreMotion

struct HeartRateReading: Identifiable {
    let id = UUID()
    let heartRate: Double
    let timestamp: Date
}

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    
    @Published var heartRate: Double = 0
    @Published var isAuthorized: Bool = false
    @Published var heartRateHistory: [HeartRateReading] = []

    // Dashboard metrics
    @Published var useMockData: Bool = false
    @Published var vo2Max: Double?        // mL/kg/min
    @Published var sleepScore: Int?       // 0-100 mock score derived
    @Published var spo2Avg: Double?       // percent
    @Published var bloodOxygenSamples: [Double] = []
    @Published var stepCount: Int = 0
    @Published var distanceTodayMeters: Double = 0
    @Published var exerciseMinutesToday: Int = 0
    @Published var recentWorkouts: [HKWorkout] = []

    // Persistent anchors for background delivery (secure coded into UserDefaults)
    private let hrAnchorKey = "HKAnchor_HeartRate"
    private let stepsAnchorKey = "HKAnchor_Steps"
    private let spo2AnchorKey = "HKAnchor_SpO2"
    private let distanceAnchorKey = "HKAnchor_DistanceWalkRun"
    private let exerciseAnchorKey = "HKAnchor_AppleExerciseTime"
    private let workoutsAnchorKey = "HKAnchor_Workouts"

    // Guards to avoid duplicate setups
    private var liveSyncStarted = false
    private var pedometerStarted = false
    // Cutoff to prevent double counting when priming dashboard + draining initial anchors
    private var primeCutoffDate: Date?

    private init() {}

    // MARK: - Convenience API
    func startHeartRateMonitoring() {
        // Bridge existing continuous sync to button in UI
        Task { await startContinuousSync() }
    }

    // MARK: - Continuous Sync Bootstrap

    func startContinuousSync() async {
        guard !liveSyncStarted else { return }
        liveSyncStarted = true
        // Invalidate previous poll timer if any
        pollTimer?.invalidate()
        pollTimer = nil

        #if targetEnvironment(simulator)
        setupMockModeAndSchedule()
        #else
        guard HKHealthStore.isHealthDataAvailable() else {
            setupMockModeAndSchedule()
            return
        }

        do {
            let authorized = try await requestAuthorization()
            self.isAuthorized = authorized
            if !authorized {
                setupMockModeAndSchedule()
                return
            }
        } catch {
            print("Authorization error: \(error)")
            setupMockModeAndSchedule()
            return
        }

        // Establish cutoff BEFORE starting observers to avoid double counting
        self.primeCutoffDate = Date()

        // Enable background delivery and observers
        await enableBackgroundDelivery()
        setupObservers()

        // Optionally start pedometer updates for iPhone step near-real-time
        startPedometerIfAvailable()

        // Prime dashboard metrics (fetch latest snapshot for UI)
        await fetchAllDashboardMetrics()
        // Also push a summary snapshot
        await syncSummaryMetricsToSupabase()
        // Schedule periodic polling for VO2 Max and Sleep (no real-time API)
        scheduleSummaryPolling()
        #endif
    }

    private func setupMockModeAndSchedule() {
        self.useMockData = true
        startMockLiveTimers()
        scheduleSummaryPolling()
    }

    // Periodic polling for summary metrics
    private var pollTimer: Timer?
    private func scheduleSummaryPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.fetchAllDashboardMetrics()
                await self.syncSummaryMetricsToSupabase()
            }
        }
    }

    // MARK: - Mock live timers (simulator / no permission)
    private func startMockLiveTimers() {
        // Heart Rate mock ticker
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let val = Double.random(in: 60...100)
            let reading = HeartRateReading(heartRate: val, timestamp: Date())
            Task { @MainActor in
                self.heartRate = val
                self.heartRateHistory.append(reading)
                // Optional: push to Supabase even in mock to keep caretaker demo working
                await self.pushMetricToSupabase(metric: "HEART_RATE", value: val, unit: "BPM", date: Date())
            }
        }
        // Steps mock ticker
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                self.stepCount += Int.random(in: 20...80)
                await self.pushMetricToSupabase(metric: "STEPS", value: Double(self.stepCount), unit: "steps", date: Date())
            }
        }
        // SpO2 mock ticker
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            let sample = Double.random(in: 95...99)
            Task { @MainActor in
                self.spo2Avg = sample
                self.bloodOxygenSamples.append(sample)
                self.bloodOxygenSamples = Array(self.bloodOxygenSamples.suffix(20))
                await self.pushMetricToSupabase(metric: "BLOOD_OXYGEN", value: sample, unit: "%", date: Date())
            }
        }
        // Distance mock ticker
        Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { _ in
            Task { @MainActor in
                self.distanceTodayMeters += Double.random(in: 15...50)
                await self.pushMetricToSupabase(metric: "DISTANCE", value: self.distanceTodayMeters, unit: "m", date: Date())
            }
        }
        // Exercise minutes mock ticker
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                self.exerciseMinutesToday += 1
                await self.pushMetricToSupabase(metric: "EXERCISE_MINUTES", value: Double(self.exerciseMinutesToday), unit: "min", date: Date())
            }
        }
    }

    // MARK: - Background Delivery

    private func enableBackgroundDelivery() async {
        let types: [HKObjectType] = [
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.workoutType()
        ].compactMap { $0 }
        for t in types {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                healthStore.enableBackgroundDelivery(for: t, frequency: .immediate) { success, error in
                    if let error { print("enableBackgroundDelivery error: \(error)") }
                    c.resume()
                }
            }
        }
    }

    private func setupObservers() {
        // Heart Rate
        if let type = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard let self = self else { completion(); return }
                if let error { print("HR observer error: \(error)"); completion(); return }
                Task { @MainActor in
                    self.runAnchoredQuery(for: type, anchorKey: self.hrAnchorKey, unit: HKUnit.count().unitDivided(by: .minute()), metric: "HEART_RATE") {
                        completion()
                    }
                }
            }
            healthStore.execute(q)
        }
        // Steps
        if let type = HKObjectType.quantityType(forIdentifier: .stepCount) {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard let self = self else { completion(); return }
                if let error { print("Steps observer error: \(error)"); completion(); return }
                Task { @MainActor in
                    self.runAnchoredQuery(for: type, anchorKey: self.stepsAnchorKey, unit: .count(), metric: "STEPS") {
                        completion()
                    }
                }
            }
            healthStore.execute(q)
        }
        // SpO2
        if let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard let self = self else { completion(); return }
                if let error { print("SpO2 observer error: \(error)"); completion(); return }
                Task { @MainActor in
                    self.runAnchoredQuery(for: type, anchorKey: self.spo2AnchorKey, unit: .percent(), metric: "BLOOD_OXYGEN", transform: { $0 * 100.0 }) {
                        completion()
                    }
                }
            }
            healthStore.execute(q)
        }
        // Distance walking/running
        if let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard let self = self else { completion(); return }
                if let error { print("Distance observer error: \(error)"); completion(); return }
                Task { @MainActor in
                    self.runAnchoredQuery(for: type, anchorKey: self.distanceAnchorKey, unit: .meter(), metric: "DISTANCE") {
                        completion()
                    }
                }
            }
            healthStore.execute(q)
        }
        // Exercise minutes
        if let type = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard let self = self else { completion(); return }
                if let error { print("Exercise observer error: \(error)"); completion(); return }
                Task { @MainActor in
                    self.runAnchoredQuery(for: type, anchorKey: self.exerciseAnchorKey, unit: .minute(), metric: "EXERCISE_MINUTES") {
                        completion()
                    }
                }
            }
            healthStore.execute(q)
        }
        // Workouts
        let wType = HKObjectType.workoutType()
        let wObserver = HKObserverQuery(sampleType: wType, predicate: nil) { [weak self] _, completion, error in
            guard let self = self else { completion(); return }
            if let error { print("Workout observer error: \(error)"); completion(); return }
            Task { @MainActor in
                self.runWorkoutAnchoredQuery(anchorKey: self.workoutsAnchorKey) {
                    completion()
                }
            }
        }
        healthStore.execute(wObserver)
    }

    private func runAnchoredQuery(for type: HKQuantityType,
                                  anchorKey: String,
                                  unit: HKUnit,
                                  metric: String,
                                  transform: ((Double) -> Double)? = nil,
                                  completion: @escaping () -> Void) {
        let startAnchor = loadAnchor(forKey: anchorKey)
        let query = HKAnchoredObjectQuery(type: type, predicate: nil, anchor: startAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samples, deleted, newAnchor, error in
            defer { completion() }
            guard let self = self else { return }
            if let error { print("Anchored query error for \(metric): \(error)"); return }
            self.saveAnchor(newAnchor, forKey: anchorKey)
            guard let qSamples = samples as? [HKQuantitySample], !qSamples.isEmpty else { return }
            Task { @MainActor in
                await self.handleQuantitySamples(qSamples, unit: unit, metric: metric, transform: transform)
            }
        }
        query.updateHandler = { [weak self] _, samples, deleted, newAnchor, error in
            guard let self = self else { return }
            if let error { print("Anchored update error for \(metric): \(error)"); return }
            self.saveAnchor(newAnchor, forKey: anchorKey)
            guard let qSamples = samples as? [HKQuantitySample], !qSamples.isEmpty else { return }
            Task { @MainActor in
                await self.handleQuantitySamples(qSamples, unit: unit, metric: metric, transform: transform)
            }
        }
        healthStore.execute(query)
    }

    private func runWorkoutAnchoredQuery(anchorKey: String, completion: @escaping () -> Void) {
        let startAnchor = loadAnchor(forKey: anchorKey)
        let wType = HKObjectType.workoutType()
        let query = HKAnchoredObjectQuery(type: wType, predicate: nil, anchor: startAnchor, limit: HKObjectQueryNoLimit) { [weak self] _, samples, deleted, newAnchor, error in
            defer { completion() }
            guard let self = self else { return }
            if let error { print("Workout anchored error: \(error)"); return }
            self.saveAnchor(newAnchor, forKey: anchorKey)
            let workouts = (samples as? [HKWorkout]) ?? []
            Task { @MainActor in
                // Keep a short recent list
                self.recentWorkouts = Array((self.recentWorkouts + workouts).suffix(10))
                // Optionally push a simple metric for each new workout (duration in minutes)
                for w in workouts { await self.pushMetricToSupabase(metric: "WORKOUT_DURATION_MIN", value: w.duration/60.0, unit: "min", date: w.endDate) }
            }
        }
        query.updateHandler = { [weak self] _, samples, deleted, newAnchor, error in
            guard let self = self else { return }
            if let error { print("Workout anchored update error: \(error)"); return }
            self.saveAnchor(newAnchor, forKey: anchorKey)
            let workouts = (samples as? [HKWorkout]) ?? []
            Task { @MainActor in
                self.recentWorkouts = Array((self.recentWorkouts + workouts).suffix(10))
                for w in workouts { await self.pushMetricToSupabase(metric: "WORKOUT_DURATION_MIN", value: w.duration/60.0, unit: "min", date: w.endDate) }
            }
        }
        healthStore.execute(query)
    }

    @MainActor
    private func handleQuantitySamples(_ samples: [HKQuantitySample], unit: HKUnit, metric: String, transform: ((Double) -> Double)? = nil) async {
        for s in samples.sorted(by: { $0.endDate < $1.endDate }) { // ensure chronological
            // Skip samples at or before cutoff to avoid double counting after initial prime
            if let cutoff = primeCutoffDate, s.endDate <= cutoff {
                continue
            }
            var value = s.quantity.doubleValue(for: unit)
            if let transform { value = transform(value) }
            switch metric {
            case "HEART_RATE":
                self.heartRate = value
                self.heartRateHistory.append(.init(heartRate: value, timestamp: s.endDate))
                await pushMetricToSupabase(metric: metric, value: value, unit: "BPM", date: s.endDate)
            case "STEPS":
                // Aggregate into stepCount for UI (today's total) while still pushing individual samples
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                if s.endDate >= startOfDay { self.stepCount += Int(value) }
                await pushMetricToSupabase(metric: metric, value: value, unit: "steps", date: s.endDate)
            case "BLOOD_OXYGEN":
                self.bloodOxygenSamples.append(value)
                self.bloodOxygenSamples = Array(self.bloodOxygenSamples.suffix(20))
                self.spo2Avg = (self.bloodOxygenSamples.reduce(0,+) / Double(self.bloodOxygenSamples.count))
                await pushMetricToSupabase(metric: metric, value: value, unit: "%", date: s.endDate)
            case "DISTANCE":
                let now = Date(); let startOfDay = Calendar.current.startOfDay(for: now)
                if s.endDate >= startOfDay { self.distanceTodayMeters += value }
                await pushMetricToSupabase(metric: metric, value: value, unit: "m", date: s.endDate)
            case "EXERCISE_MINUTES":
                let now = Date(); let startOfDay = Calendar.current.startOfDay(for: now)
                if s.endDate >= startOfDay { self.exerciseMinutesToday += Int(value) }
                await pushMetricToSupabase(metric: metric, value: value, unit: "min", date: s.endDate)
            default:
                break
            }
        }
    }

    // MARK: - Anchor persistence
    nonisolated private func saveAnchor(_ anchor: HKQueryAnchor?, forKey key: String) {
        guard let anchor else { return }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to archive anchor: \(error)")
        }
    }
    nonisolated private func loadAnchor(forKey key: String) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
                return anchor
            }
        } catch {
            print("Failed to unarchive anchor: \(error)")
        }
        return nil
    }

    // MARK: - CMPedometer
    private func startPedometerIfAvailable() {
        guard !pedometerStarted else { return }
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometerStarted = true
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self = self else { return }
            if let error { print("Pedometer error: \(error)"); return }
            guard let data else { return }
            let steps = data.numberOfSteps.intValue
            Task { @MainActor in
                self.stepCount = steps
                // Avoid pushing via pedometer to prevent duplicates; HK observers persist samples
            }
        }
    }

    // MARK: - Existing APIs (authorization updated)
    func requestAuthorization() async throws -> Bool {
        #if targetEnvironment(simulator)
        self.useMockData = true
        self.isAuthorized = true
        loadMockDashboardData()
        return true
        #endif
        guard HKHealthStore.isHealthDataAvailable() else {
            self.useMockData = true
            self.isAuthorized = false
            loadMockDashboardData()
            return false
        }
        var readTypes = Set<HKObjectType>()
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { readTypes.insert(hr) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { readTypes.insert(rhr) }
        if let vo2 = HKObjectType.quantityType(forIdentifier: .vo2Max) { readTypes.insert(vo2) }
        if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { readTypes.insert(spo2) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(sleep) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { readTypes.insert(steps) }
        if let dist = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { readTypes.insert(dist) }
        if let ex = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { readTypes.insert(ex) }
        readTypes.insert(HKObjectType.workoutType())
        
        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: success)
            }
        }
        self.isAuthorized = success
        if !success { // use mock fallback if permission denied
            self.useMockData = true
            loadMockDashboardData()
        }
        return success
    }

    // MARK: - Dashboard fetching (stubs to be implemented with real HK queries)
    @MainActor
    func fetchAllDashboardMetrics() async {
        await fetchVO2Max()
        await fetchSpO2()
        await fetchSleepScore()
        // Fetch today's snapshot for steps, distance and exercise minutes
        await fetchTodayActivitySums()
        // Fetch an initial list of recent workouts so UI isn't empty at launch
        await fetchRecentWorkouts()
    }

    @MainActor
    private func fetchRecentWorkouts(limit: Int = 10) async {
        let type = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        do {
            let samples = try await withCheckedThrowingContinuation { (c: CheckedContinuation<[HKSample], Error>) in
                let q = HKSampleQuery(sampleType: type, predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                    if let error { c.resume(throwing: error) } else { c.resume(returning: samples ?? []) }
                }
                self.healthStore.execute(q)
            }
            self.recentWorkouts = (samples as? [HKWorkout]) ?? []
        } catch {
            print("Failed to fetch recent workouts: \(error)")
        }
    }

    @MainActor
    private func fetchVO2Max() async {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples ?? []) }
                }
                healthStore.execute(query)
            }
            
            if let sample = samples.first as? HKQuantitySample {
                let unit = HKUnit(from: "mL/min/kg")
                self.vo2Max = sample.quantity.doubleValue(for: unit)
            } else {
                self.vo2Max = nil
            }
        } catch {
            print("Failed to fetch VO2Max: \(error)")
            self.vo2Max = nil
        }
    }

    @MainActor
    private func fetchSpO2() async {
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples ?? []) }
                }
                healthStore.execute(query)
            }
            
            let qSamples = (samples as? [HKQuantitySample]) ?? []
            let percents: [Double] = qSamples.map { $0.quantity.doubleValue(for: .percent()) * 100.0 }
            let avg = percents.isEmpty ? nil : (percents.reduce(0, +) / Double(percents.count))
            self.spo2Avg = avg
            self.bloodOxygenSamples = Array(percents.prefix(20).reversed())
            
        } catch {
            print("Failed to fetch SpO2: \(error)")
        }
    }

    @MainActor
    private func fetchSleepScore() async {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples ?? []) }
                }
                healthStore.execute(query)
            }
            
            let cat = (samples as? [HKCategorySample]) ?? []
            let asleepSeconds = cat.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let hours = asleepSeconds / 3600.0
            let score = max(0, min(100, Int((hours / 8.0) * 100.0)))
            self.sleepScore = score
        } catch {
            print("Failed to fetch sleep score: \(error)")
        }
    }

    // Today's steps, distance and exercise minutes
    @MainActor
    private func fetchTodayActivitySums() async {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        // Steps
        if let type = HKObjectType.quantityType(forIdentifier: .stepCount) {
            if let sum = try? await statisticsSum(for: type, start: startOfDay, end: now, options: .cumulativeSum) {
                self.stepCount = Int(sum.doubleValue(for: .count()))
            }
        }
        // Distance
        if let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            if let sum = try? await statisticsSum(for: type, start: startOfDay, end: now, options: .cumulativeSum) {
                self.distanceTodayMeters = sum.doubleValue(for: .meter())
            }
        }
        // Exercise minutes
        if let type = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            if let sum = try? await statisticsSum(for: type, start: startOfDay, end: now, options: .cumulativeSum) {
                self.exerciseMinutesToday = Int(sum.doubleValue(for: .minute()))
            }
        }
    }

    private func statisticsSum(for type: HKQuantityType, start: Date, end: Date, options: HKStatisticsOptions) async throws -> HKQuantity? {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<HKQuantity?, Error>) in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, result, error in
                if let error { c.resume(throwing: error) } else { c.resume(returning: result?.sumQuantity()) }
            }
            self.healthStore.execute(q)
        }
    }

    // MARK: - Data Syncing with Supabase (existing one-off methods retained)

    func fetchAndSyncHeartRate() async {
        guard let uid = SupabaseService.shared.currentUser?.id else { return }
        if useMockData { // fallback path when simulator or permission denied
            let value = heartRate == 0 ? Double.random(in: 65...85) : heartRate
            let record = SupabaseService.HealthRecordInput(
                user_id: uid,
                metric_type: "HEART_RATE",
                metric_value: value,
                unit_of_measurement: "BPM",
                recorded_date: ISO8601DateFormatter().string(from: Date()),
                data_source: "HealthKit"
            )
            do { try await SupabaseService.shared.addHealthRecord(record); await MainActor.run { self.heartRate = value } } catch { print(error) }
            return
        }
        #if targetEnvironment(simulator)
        // Mock data for simulator
        let mockValue = Double.random(in: 65...85)
        let record = SupabaseService.HealthRecordInput(
            user_id: uid,
            metric_type: "HEART_RATE",
            metric_value: mockValue,
            unit_of_measurement: "BPM",
            recorded_date: ISO8601DateFormatter().string(from: Date()),
            data_source: "HealthKit"
        )
        do { try await SupabaseService.shared.addHealthRecord(record); self.heartRate = mockValue } catch { print(error) }
        return
        #endif

        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        do {
            let sample = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantitySample?, Error>) in
                let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples?.first as? HKQuantitySample)
                    }
                }
                healthStore.execute(query)
            }
            
            guard let sample else {
                print("No heart rate sample found to sync.")
                return
            }
            
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let value = sample.quantity.doubleValue(for: heartRateUnit)
            
            await MainActor.run { self.heartRate = value }
            
            let record = SupabaseService.HealthRecordInput(
                user_id: uid,
                metric_type: "HEART_RATE",
                metric_value: value,
                unit_of_measurement: "BPM",
                recorded_date: ISO8601DateFormatter().string(from: sample.endDate),
                data_source: "HealthKit"
            )
            
            try await SupabaseService.shared.addHealthRecord(record)
            print("Successfully synced heart rate: \(value) BPM")
            
        } catch {
            print("Failed to fetch or sync heart rate: \(error)")
        }
    }

    func fetchAndSyncSteps() async {
        guard let uid = SupabaseService.shared.currentUser?.id else { return }
        if useMockData {
            let value = stepCount == 0 ? Double.random(in: 3000...9000) : Double(stepCount)
            let record = SupabaseService.HealthRecordInput(
                user_id: uid,
                metric_type: "STEPS",
                metric_value: value,
                unit_of_measurement: "steps",
                recorded_date: ISO8601DateFormatter().string(from: Date()),
                data_source: "HealthKit"
            )
            do { try await SupabaseService.shared.addHealthRecord(record); await MainActor.run { self.stepCount = Int(value) } } catch { print(error) }
            return
        }
        #if targetEnvironment(simulator)
        // Mock data for simulator
        let mockValue = Double.random(in: 3000...9000)
        let record = SupabaseService.HealthRecordInput(
            user_id: uid,
            metric_type: "STEPS",
            metric_value: mockValue,
            unit_of_measurement: "steps",
            recorded_date: ISO8601DateFormatter().string(from: Date()),
            data_source: "HealthKit"
        )
        do { try await SupabaseService.shared.addHealthRecord(record); self.stepCount = Int(mockValue) } catch { print(error) }
        return
        #endif

        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        do {
            let sum = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantity?, Error>) in
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
                let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result?.sumQuantity())
                    }
                }
                healthStore.execute(query)
            }
            
            guard let sum else {
                print("No step data found to sync.")
                return
            }

            let value = sum.doubleValue(for: .count())
            await MainActor.run { self.stepCount = Int(value) }
            
            let record = SupabaseService.HealthRecordInput(
                user_id: uid,
                metric_type: "STEPS",
                metric_value: value,
                unit_of_measurement: "steps",
                recorded_date: ISO8601DateFormatter().string(from: Date()),
                data_source: "HealthKit"
            )
            
            try await SupabaseService.shared.addHealthRecord(record)
            print("Successfully synced steps: \(value)")
            
        } catch {
            print("Failed to fetch or sync steps: \(error)")
        }
    }

    /// Sync VO2_MAX, SLEEP_QUALITY, BLOOD_OXYGEN summary metrics to Supabase as single latest rows
    func syncSummaryMetricsToSupabase() async {
        guard let uid = SupabaseService.shared.currentUser?.id else { return }
        let isoNow = ISO8601DateFormatter().string(from: Date())
        if useMockData { // unified mock path for simulator OR no permission
            if vo2Max == nil || sleepScore == nil || spo2Avg == nil { loadMockDashboardData() }
            let payloads: [SupabaseService.HealthRecordInput] = [
                .init(user_id: uid, metric_type: "VO2_MAX", metric_value: vo2Max ?? 42.5, unit_of_measurement: "mL/kg/min", recorded_date: isoNow, data_source: "HealthKit"),
                .init(user_id: uid, metric_type: "SLEEP_QUALITY", metric_value: Double(sleepScore ?? 84), unit_of_measurement: "score", recorded_date: isoNow, data_source: "HealthKit"),
                .init(user_id: uid, metric_type: "BLOOD_OXYGEN", metric_value: spo2Avg ?? 97.0, unit_of_measurement: "%", recorded_date: isoNow, data_source: "HealthKit")
            ]
            for p in payloads { try? await SupabaseService.shared.addHealthRecord(p) }
            return
        }
        // Device path: fetch latest samples and send
        do {
            // VO2_MAX
            if let type = HKObjectType.quantityType(forIdentifier: .vo2Max) {
                let s = try await latestQuantitySample(for: type)
                if let s { let val = s.quantity.doubleValue(for: HKUnit(from: "mL/min/kg"));
                    let rec = SupabaseService.HealthRecordInput(user_id: uid, metric_type: "VO2_MAX", metric_value: val, unit_of_measurement: "mL/kg/min", recorded_date: ISO8601DateFormatter().string(from: s.endDate), data_source: "HealthKit");
                    try? await SupabaseService.shared.addHealthRecord(rec); self.vo2Max = val }
            }
            // SLEEP_QUALITY (derive hours last 24h -> score 0..100)
            if let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                let now = Date(); let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
                let cat = try await categorySamples(for: type, start: start, end: now)
                let asleepSeconds = cat.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let hours = asleepSeconds/3600.0; let score = max(0, min(100, Int((hours/8.0)*100)))
                let rec = SupabaseService.HealthRecordInput(user_id: uid, metric_type: "SLEEP_QUALITY", metric_value: Double(score), unit_of_measurement: "score", recorded_date: isoNow, data_source: "HealthKit")
                try? await SupabaseService.shared.addHealthRecord(rec); self.sleepScore = score
            }
            // BLOOD_OXYGEN average last 24h
            if let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
                let now = Date(); let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
                let q = try await quantitySamples(for: type, start: start, end: now)
                let percents = q.map { $0.quantity.doubleValue(for: .percent()) * 100.0 }
                if let avg = percents.average { let rec = SupabaseService.HealthRecordInput(user_id: uid, metric_type: "BLOOD_OXYGEN", metric_value: avg, unit_of_measurement: "%", recorded_date: isoNow, data_source: "HealthKit"); try? await SupabaseService.shared.addHealthRecord(rec); self.spo2Avg = avg; self.bloodOxygenSamples = Array(percents.prefix(20).reversed()) }
            }
        } catch { print("Summary sync error: \(error)") }
    }

    // MARK: - Small helpers for device path
    private func latestQuantitySample(for type: HKQuantityType) async throws -> HKQuantitySample? {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<HKQuantitySample?, Error>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error { c.resume(throwing: error) } else { c.resume(returning: samples?.first as? HKQuantitySample) }
            }
            self.healthStore.execute(q)
        }
    }
    private func quantitySamples(for type: HKQuantityType, start: Date, end: Date) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<[HKQuantitySample], Error>) in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { c.resume(throwing: error) } else { c.resume(returning: (samples as? [HKQuantitySample]) ?? []) }
            }
            self.healthStore.execute(q)
        }
    }
    private func categorySamples(for type: HKCategoryType, start: Date, end: Date) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<[HKCategorySample], Error>) in
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { c.resume(throwing: error) } else { c.resume(returning: (samples as? [HKCategorySample]) ?? []) }
            }
            self.healthStore.execute(q)
        }
    }

    // MARK: - Supabase push helper
    private func pushMetricToSupabase(metric: String, value: Double, unit: String, date: Date) async {
        guard let uid = SupabaseService.shared.currentUser?.id else { return }
        let rec = SupabaseService.HealthRecordInput(
            user_id: uid,
            metric_type: metric,
            metric_value: value,
            unit_of_measurement: unit,
            recorded_date: ISO8601DateFormatter().string(from: date),
            data_source: "HealthKit"
        )
        do {
            try await SupabaseService.shared.upsertHealthRecord(rec)
        } catch {
            print("Supabase upsert failed for \(metric): \(error)")
        }
    }
}

private extension Array where Element == Double {
    var average: Double? { guard !isEmpty else { return nil }; return reduce(0,+)/Double(count) }
}

// MARK: - Mock fallback values for Simulator or no permission
private extension HealthKitManager {
    func loadMockDashboardData() {
        // Reasonable demo values for simulator UI
        self.vo2Max = 42.5
        self.sleepScore = 84
        self.spo2Avg = 97.0
        self.bloodOxygenSamples = [95, 96, 97, 98, 97, 96, 98]
        self.stepCount = 8500
        self.heartRate = 72
    }
}
