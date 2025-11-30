import SwiftUI

struct WellnessDetailView: View {
    @ObservedObject var viewModel: WellnessViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Main score
                    if let score = viewModel.currentScore {
                        VStack(spacing: 16) {
                            Text("Overall Wellness")
                                .font(.headline)
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 24)
                                
                                Circle()
                                    .trim(from: 0, to: score.totalScore / 100)
                                    .stroke(Gradient(colors: [.blue, .green]),
                                           style: StrokeStyle(lineWidth: 24, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 8) {
                                    Text("\(score)")  // ✅ CORRECT - uses string interpolation

                                        .font(.system(size: 56, weight: .bold))
                                    Text(score.category)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(height: 240)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                        
                        // Component breakdown
                        VStack(spacing: 12) {
                            Text("Component Breakdown")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            ComponentRowView(name: "Cardiovascular Fitness",
                                           score: score.cardiovascularFitness,
                                           maxScore: 10,
                                           color: .purple)
                            
                            ComponentRowView(name: "Sleep Quality",
                                           score: score.sleepQuality,
                                           maxScore: 10,
                                           color: .blue)
                            
                            ComponentRowView(name: "Physical Activity",
                                           score: score.physicalActivity,
                                           maxScore: 10,
                                           color: .green)
                            
                            ComponentRowView(name: "Heart Health",
                                           score: score.heartHealth,
                                           maxScore: 10,
                                           color: .red)
                            
                            ComponentRowView(name: "Recovery",
                                           score: score.recovery,
                                           maxScore: 10,
                                           color: .orange)
                            
                            ComponentRowView(name: "Consistency",
                                           score: score.consistency,
                                           maxScore: 10,
                                           color: .cyan)
                        }
                        .padding(.horizontal)
                        
                        // Insights
                        InsightsView(score: score)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Wellness Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .task { await viewModel.loadWellnessData() }
    }
}

struct ComponentRowView: View {
    let name: String
    let score: Double
    let maxScore: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f/%.0f", score, maxScore))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * (score / maxScore))
                }
            }
            .frame(height: 10)
            .cornerRadius(5)
        }
        .padding(.horizontal)
    }
}

struct InsightsView: View {
    let score: WellnessScoreComponents
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights & Recommendations")
                .font(.headline)
            
            if score.category == "Excellent" {
                insightCard(
                    title: "Great Work!",
                    message: "You're maintaining excellent health. Keep up the great habits!",
                    icon: "star.fill",
                    color: .green
                )
            } else if score.cardiovascularFitness < 5 {
                insightCard(
                    title: "Boost Cardio",
                    message: "Try increasing aerobic exercise like running or cycling.",
                    icon: "heart.fill",
                    color: .red
                )
            }
            
            if score.sleepQuality < 5 {
                insightCard(
                    title: "Improve Sleep",
                    message: "Aim for 7-8 hours and maintain a consistent sleep schedule.",
                    icon: "moon.stars.fill",
                    color: .orange
                )
            }
            
            if score.physicalActivity < 5 {
                insightCard(
                    title: "Increase Activity",
                    message: "Target 10,000 steps and 30 minutes of exercise daily.",
                    icon: "figure.walk",
                    color: .blue
                )
            }
        }
    }
    
    @ViewBuilder
    private func insightCard(title: String, message: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    WellnessDetailView(viewModel: WellnessViewModel())
}
//
//  WellnessDetailView.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 27/11/25.
//

