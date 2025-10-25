import Foundation
import HealthKit
internal import Combine

struct HeartRateReading: Identifiable {
    let id = UUID()
    let heartRate: Double
    let timestamp: Date
}

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    @Published var heartRate: Double = 0
    @Published var isAuthorized: Bool = false
    @Published var heartRateHistory: [HeartRateReading] = []

    // Dashboard metrics
    @Published var useMockData: Bool = false
    @Published var vo2Max: Double?        // mL/kg/min
    @Published var sleepScore: Int?       // 0-100 mock score derived
    @Published var spo2Avg: Double?       // percent
    @Published var bloodOxygenSamples: [Double] = []
    
    private init() {}
    
    func startHeartRateMonitoring() {
        #if targetEnvironment(simulator)
        // Mock data for simulator
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let mockHeartRate = Double.random(in: 60...100)
            let reading = HeartRateReading(
                heartRate: mockHeartRate,
                timestamp: Date()
            )
            DispatchQueue.main.async {
                self.heartRate = mockHeartRate
                self.heartRateHistory.append(reading)
            }
        }
        #else
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }
            DispatchQueue.main.async {
                if let latestSample = samples.last {
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    let heartRateValue = latestSample.quantity.doubleValue(for: heartRateUnit)
                    self.heartRate = heartRateValue
                    let reading = HeartRateReading(
                        heartRate: heartRateValue,
                        timestamp: latestSample.startDate
                    )
                    self.heartRateHistory.append(reading)
                }
            }
        }
        query.updateHandler = { query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }
            DispatchQueue.main.async {
                if let latestSample = samples.last {
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    let heartRateValue = latestSample.quantity.doubleValue(for: heartRateUnit)
                    self.heartRate = heartRateValue
                    let reading = HeartRateReading(
                        heartRate: heartRateValue,
                        timestamp: latestSample.startDate
                    )
                    self.heartRateHistory.append(reading)
                }
            }
        }
        healthStore.execute(query)
        #endif
    }
    
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            // Simulator or not available -> use mock dashboard data
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
        
        let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        self.isAuthorized = success
        if success {
            await fetchAllDashboardMetrics()
        } else {
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
    }

    @MainActor
    private func fetchVO2Max() async {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self = self else { return }
            if let sample = samples?.first as? HKQuantitySample {
                let unit = HKUnit(from: "mL/min/kg")
                let value = sample.quantity.doubleValue(for: unit)
                Task { @MainActor in
                    self.vo2Max = value
                }
            } else {
                Task { @MainActor in
                    self.vo2Max = nil
                }
            }
        }
        healthStore.execute(query)
    }

    @MainActor
    private func fetchSpO2() async {
        guard let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self = self else { return }
            let qSamples = (samples as? [HKQuantitySample]) ?? []
            let percents: [Double] = qSamples.map { $0.quantity.doubleValue(for: .percent()) * 100.0 }
            let avg = percents.isEmpty ? nil : (percents.reduce(0, +) / Double(percents.count))
            Task { @MainActor in
                self.spo2Avg = avg
                // keep last ~20 points to plot
                self.bloodOxygenSamples = Array(percents.prefix(20).reversed())
            }
        }
        healthStore.execute(query)
    }

    @MainActor
    private func fetchSleepScore() async {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let now = Date()
        // Last night window: 24h back
        let start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            guard let self = self else { return }
            let cat = (samples as? [HKCategorySample]) ?? []
            // Sum intervals where value indicates asleep
            let asleepSeconds = cat.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let hours = asleepSeconds / 3600.0
            // Simple score: 8h -> 100, 0h -> 0, clamp 0...100
            let score = max(0, min(100, Int((hours / 8.0) * 100.0)))
            Task { @MainActor in
                self.sleepScore = score
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Mock fallback values for Simulator or no permission
    private func loadMockDashboardData() {
        self.vo2Max = 42.5
        self.spo2Avg = 97.0
        self.sleepScore = 84
        self.bloodOxygenSamples = [95, 96, 97, 98, 97, 96, 98]
    }
}
