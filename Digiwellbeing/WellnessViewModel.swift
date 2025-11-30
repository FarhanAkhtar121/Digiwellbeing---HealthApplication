import Foundation
internal import Combine
internal import Auth

@MainActor
class WellnessViewModel: ObservableObject {
    @Published var currentScore: WellnessScoreComponents?
    @Published var scoreHistory: [WellnessScoreResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let calculator = WellnessScoreCalculator.shared
    private let healthManager = HealthKitManager.shared
    private let supabaseService = SupabaseService.shared
    
    func loadWellnessData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            scoreHistory = try await supabaseService.fetchWellnessScoreHistory(days: 30)
            
            let today = Calendar.current.startOfDay(for: Date())
            if let todayScore = scoreHistory.first(where: {
                Calendar.current.startOfDay(for: $0.calculatedAt) == today
            }) {
                currentScore = todayScore.toWellnessComponents()
            } else {
                await calculateDailyScore()
            }
        } catch {
            errorMessage = "Failed loading wellness: \\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func calculateDailyScore() async {
        guard let user = supabaseService.currentUser else {
            errorMessage = "Not signed in"
            return
        }
        
        do {
            guard let profile = try await supabaseService.fetchProfileComplete(userId: user.id) else {
                errorMessage = "Profile not found"
                return
            }
            
            let age = calculateAge(from: profile.date_of_birth)
            let score = calculator.calculateWellnessScore(
                vo2Max: healthManager.vo2Max,
                age: age,
                gender: profile.gender ?? "unknown",
                totalSleepHours: healthManager.sleepHoursLastNight,
                deepSleepHours: nil,
                remSleepHours: nil,
                sleepAwakenings: nil,
                minutesAwake: nil,
                steps: healthManager.stepCount > 0 ? healthManager.stepCount : nil,
                activeMinutes: healthManager.exerciseMinutesToday > 0 ? healthManager.exerciseMinutesToday : nil,
                workoutMinutes: nil,
                restingHeartRate: healthManager.restingHeartRate,
                bloodOxygen: healthManager.spo2Avg,
                hrv: nil,
                last7DayScores: score7DayTrend()
            )
            
            currentScore = score
            try await supabaseService.saveWellnessScore(score)
        } catch {
            errorMessage = "Calculation failed: \\(error.localizedDescription)"
        }
    }
    
    func getScoreTrend() -> Double {
        guard scoreHistory.count >= 2 else { return 0 }
        let sorted = scoreHistory.sorted(by: { $0.calculatedAt < $1.calculatedAt })
                let last = sorted[sorted.count - 1].total_wellness_score
                let previous = sorted[sorted.count - 2].total_wellness_score
                return last - previous
    }
    
    private func calculateAge(from dateString: String?) -> Int {
        guard let dateString = dateString else { return 30 }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return 30 }
        let calendar = Calendar.current
        return calendar.dateComponents([.year], from: date, to: Date()).year ?? 30
    }
    
    private func score7DayTrend() -> [Double]? {
        guard scoreHistory.count >= 7 else { return nil }
        return Array(scoreHistory.prefix(7)).map { $0.total_wellness_score }
    }
}

struct WellnessScoreResponse: Decodable, Identifiable, Sendable {
    let score_id: UUID
    let user_id: UUID
    let cardiovascular_fitness_score: Double
    let sleep_quality_score: Double
    let physical_activity_score: Double
    let heart_health_score: Double
    let recovery_score: Double
    let consistency_score: Double
    let total_wellness_score: Double
    let score_category: String
    let calculated_at: String
    
    var id: UUID { score_id }
    var calculatedAt: Date {
        ISO8601DateFormatter().date(from: calculated_at) ?? Date()
    }
    
    func toWellnessComponents() -> WellnessScoreComponents {
        WellnessScoreComponents(
            cardiovascularFitness: cardiovascular_fitness_score,
            sleepQuality: sleep_quality_score,
            physicalActivity: physical_activity_score,
            heartHealth: heart_health_score,
            recovery: recovery_score,
            consistency: consistency_score,
            totalScore: total_wellness_score,
            category: score_category,
            calculatedAt: calculatedAt
        )
    }
}
//
//  WellnessViewModel.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 27/11/25.
//

