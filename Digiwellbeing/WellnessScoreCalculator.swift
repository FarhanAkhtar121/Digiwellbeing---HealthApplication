import Foundation

// MARK: - Core Models

struct WellnessScoreComponents: Codable, Sendable {
    let cardiovascularFitness: Double      // 0-10
    let sleepQuality: Double               // 0-10
    let physicalActivity: Double           // 0-10
    let heartHealth: Double                // 0-10
    let recovery: Double                   // 0-10
    let consistency: Double                // 0-10
    let totalScore: Double                 // 0-100
    let category: String                   // Excellent, Good, Fair, etc
    let calculatedAt: Date
}

// MARK: - Calculation Engine

class WellnessScoreCalculator {
    static let shared = WellnessScoreCalculator()
    
    private init() {}
    
    /// Main calculation method - all-in-one wellness score
    func calculateWellnessScore(
        vo2Max: Double?,
        age: Int,
        gender: String,
        totalSleepHours: Double?,
        deepSleepHours: Double?,
        remSleepHours: Double?,
        sleepAwakenings: Int?,
        minutesAwake: Double?,
        steps: Int?,
        activeMinutes: Int?,
        workoutMinutes: Int?,
        restingHeartRate: Double?,
        bloodOxygen: Double?,
        hrv: Double?,
        last7DayScores: [Double]?
    ) -> WellnessScoreComponents {
        
        // Calculate component scores (each 0-10)
        let cardioScore = calculateVO2MaxScore(vo2Max: vo2Max, age: age, gender: gender)
        let sleepScore = calculateSleepScore(
            totalHours: totalSleepHours,
            deepHours: deepSleepHours,
            remHours: remSleepHours,
            awakenings: sleepAwakenings,
            minutesAwake: minutesAwake
        )
        let activityScore = calculateActivityScore(
            steps: steps,
            activeMinutes: activeMinutes,
            workoutMinutes: workoutMinutes
        )
        let heartScore = calculateHeartScore(
            restingHR: restingHeartRate,
            bloodOx: bloodOxygen,
            age: age
        )
        let recoveryScore = calculateRecoveryScore(hrv: hrv, age: age)
        let consistencyScore = calculateConsistencyScore(historicalScores: last7DayScores)
        
        // Weight-based total (0-100)
        let weights = [0.25, 0.25, 0.20, 0.15, 0.10, 0.05]
        let scores = [cardioScore, sleepScore, activityScore, heartScore, recoveryScore, consistencyScore]
        let weightedTotal = zip(scores, weights).map(*).reduce(0, +) * 10
        
        let category = categorizeScore(weightedTotal)
        
        return WellnessScoreComponents(
            cardiovascularFitness: cardioScore,
            sleepQuality: sleepScore,
            physicalActivity: activityScore,
            heartHealth: heartScore,
            recovery: recoveryScore,
            consistency: consistencyScore,
            totalScore: weightedTotal,
            category: category,
            calculatedAt: Date()
        )
    }
    
    // MARK: - Individual Scorers
    
    private func calculateVO2MaxScore(vo2Max: Double?, age: Int, gender: String) -> Double {
        guard let vo2Max = vo2Max else { return 5.0 }
        
        let benchmarks: [String: [Int: (excellent: Double, good: Double, fair: Double)]] = [
            "male": [20: (55, 48, 41), 30: (52, 45, 38), 40: (48, 42, 35), 50: (43, 37, 30), 60: (39, 33, 26)],
            "female": [20: (49, 42, 35), 30: (45, 38, 31), 40: (41, 34, 27), 50: (37, 30, 23), 60: (33, 26, 19)]
        ]
        
        let ageBracket = (age / 10) * 10
        guard let genderData = benchmarks[gender.lowercased()],
              let benchmark = genderData[ageBracket] else { return 5.0 }
        
        if vo2Max >= benchmark.excellent { return 10.0 }
        else if vo2Max >= benchmark.good { return 7.5 }
        else if vo2Max >= benchmark.fair { return 5.0 }
        else if vo2Max >= benchmark.fair * 0.85 { return 3.0 }
        else { return 1.0 }
    }
    
    private func calculateSleepScore(
        totalHours: Double?,
        deepHours: Double?,
        remHours: Double?,
        awakenings: Int?,
        minutesAwake: Double?
    ) -> Double {
        guard let totalHours = totalHours else { return 5.0 }
        
        var score = 0.0
        
        // Duration (max 5)
        if totalHours >= 7.83 { score += 5.0 }
        else if totalHours >= 7.0 { score += 4.5 }
        else if totalHours >= 6.5 { score += 4.0 }
        else if totalHours >= 6.0 { score += 3.0 }
        else if totalHours >= 5.0 { score += 2.0 }
        else { score += 1.0 }
        
        // Sleep stages (max 3)
        if let deep = deepHours, let rem = remHours, totalHours > 0 {
            let deepPct = deep / totalHours
            let remPct = rem / totalHours
            
            if deepPct >= 0.13 && deepPct <= 0.23 { score += 1.5 }
            else if deepPct >= 0.10 && deepPct <= 0.27 { score += 1.0 }
            else { score += 0.5 }
            
            if remPct >= 0.20 && remPct <= 0.25 { score += 1.5 }
            else if remPct >= 0.15 && remPct <= 0.30 { score += 1.0 }
            else { score += 0.5 }
        }
        
        // Interruptions (max 2)
        if let minutesAwake = minutesAwake, let awakenings = awakenings {
            if minutesAwake <= 11 && awakenings <= 2 { score += 2.0 }
            else if minutesAwake <= 25 && awakenings <= 4 { score += 1.5 }
            else if minutesAwake <= 40 && awakenings <= 6 { score += 1.0 }
            else { score += 0.5 }
        }
        
        return min(10.0, score)
    }
    
    private func calculateActivityScore(
        steps: Int?,
        activeMinutes: Int?,
        workoutMinutes: Int?
    ) -> Double {
        var score = 0.0
        
        if let steps = steps {
            if steps >= 10000 { score += 4.0 }
            else if steps >= 7500 { score += 3.5 }
            else if steps >= 5000 { score += 2.5 }
            else if steps >= 2500 { score += 1.5 }
            else { score += 0.5 }
        }
        
        if let activeMinutes = activeMinutes {
            if activeMinutes >= 40 { score += 3.0 }
            else if activeMinutes >= 25 { score += 2.5 }
            else if activeMinutes >= 15 { score += 2.0 }
            else if activeMinutes >= 10 { score += 1.0 }
            else { score += 0.5 }
        }
        
        if let workoutMinutes = workoutMinutes {
            if workoutMinutes >= 30 { score += 3.0 }
            else if workoutMinutes >= 20 { score += 2.0 }
            else if workoutMinutes >= 10 { score += 1.0 }
            else if workoutMinutes > 0 { score += 0.5 }
        }
        
        return min(10.0, score)
    }
    
    private func calculateHeartScore(restingHR: Double?, bloodOx: Double?, age: Int) -> Double {
        var score = 0.0
        
        if let rhr = restingHR {
            if rhr <= 60 { score += 6.0 }
            else if rhr <= 70 { score += 5.0 }
            else if rhr <= 80 { score += 4.0 }
            else if rhr <= 90 { score += 2.5 }
            else { score += 1.0 }
        }
        
        if let bloodOx = bloodOx {
            if bloodOx >= 97 { score += 4.0 }
            else if bloodOx >= 95 { score += 3.5 }
            else if bloodOx >= 92 { score += 2.5 }
            else if bloodOx >= 90 { score += 1.5 }
            else { score += 0.5 }
        }
        
        return min(10.0, score)
    }
    
    private func calculateRecoveryScore(hrv: Double?, age: Int) -> Double {
        guard let hrv = hrv else { return 5.0 }
        
        let baseline = age < 30 ? 60.0 : age < 40 ? 55.0 : age < 50 ? 45.0 : age < 60 ? 40.0 : 35.0
        
        if hrv >= baseline * 1.2 { return 10.0 }
        else if hrv >= baseline { return 8.0 }
        else if hrv >= baseline * 0.8 { return 6.0 }
        else if hrv >= baseline * 0.6 { return 4.0 }
        else { return 2.0 }
    }
    
    private func calculateConsistencyScore(historicalScores: [Double]?) -> Double {
        guard let scores = historicalScores, scores.count == 7 else { return 5.0 }
        
        let avg = scores.reduce(0, +) / 7
        let variance = scores.map { pow($0 - avg, 2) }.reduce(0, +) / 7
        let stdDev = sqrt(variance)
        
        if stdDev < 5 { return 10.0 }
        else if stdDev < 10 { return 8.0 }
        else if stdDev < 15 { return 6.0 }
        else if stdDev < 20 { return 4.0 }
        else { return 2.0 }
    }
    
    private func categorizeScore(_ score: Double) -> String {
        switch score {
        case 85...100: return "Excellent"
        case 70..<85: return "Good"
        case 55..<70: return "Fair"
        case 40..<55: return "Below Average"
        default: return "Needs Improvement"
        }
    }
}
//
//  WellnessScoreCalculator.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 27/11/25.
//

