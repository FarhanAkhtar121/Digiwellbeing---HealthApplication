import SwiftUI

struct WellnessScoreCard: View {
    let score: WellnessScoreComponents?
    let trend: Double
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Wellness Score")
                .font(.headline)
            
            if let score = score {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: score.totalScore / 100)
                        .stroke(scoreColor(score.totalScore), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: score.totalScore)
                    
                    VStack(spacing: 8) {
                        Text(String(format: "%.0f", score.totalScore))  // ✅ CORRECT - uses string interpolation

                            .font(.system(size: 48, weight: .bold))
                        
                        Text(score.category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if trend != 0 {
                            HStack(spacing: 4) {
                                Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                                    .foregroundColor(trend > 0 ? .green : .red)
                                Text(String(format: "%.1f", abs(trend)))
                                    .font(.caption)
                                    .foregroundColor(trend > 0 ? .green : .red)
                            }
                        }
                    }
                }
                .frame(width: 200, height: 200)
            } else {
                ProgressView()
                    .frame(width: 200, height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 85...100: return .green
        case 70..<85: return .blue
        case 55..<70: return .orange
        default: return .red
        }
    }
}

//  WellnessScoreCardView.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 27/11/25.
//

