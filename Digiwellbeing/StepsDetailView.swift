// filepath: /Users/farhanakhtar/Developer/Xcode/Digiwellbeing/Digiwellbeing/StepsDetailView.swift
import SwiftUI

struct StepsDetailView: View {
    @ObservedObject private var auth = AuthManager.shared

    // Mock data
    private let hourlySteps: [Int] = [120, 350, 560, 800, 950, 1200, 980, 760, 640, 420, 260, 180]
    private let hourlyLabels: [String] = ["6a","7a","8a","9a","10a","11a","12p","1p","2p","3p","4p","5p"]
    private let totalSteps: Int = 8650
    private let distanceKm: Double = 6.4
    private let activeCalories: [Double] = [12, 18, 22, 28, 35, 40, 33, 27, 21, 16, 14, 10]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    AppTopBar(title: "DigitalWellbeing - Health App", showLogout: true) { auth.signOut() }

                    if let name = auth.userName {
                        Text("Welcome, \(name)!")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }

                    // Header summary
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.blue)
                            Text("Steps & Distance")
                                .font(.largeTitle).bold()
                            Spacer()
                        }
                        .padding(.horizontal)

                        HStack(spacing: 16) {
                            SummaryPill(title: "Steps", value: "\(totalSteps)", color: .blue, icon: "figure.walk")
                            SummaryPill(title: "Distance", value: String(format: "%.1f km", distanceKm), color: .teal, icon: "point.topleft.down.curvedto.point.bottomright.up")
                        }
                        .padding(.horizontal)
                    }

                    // Hourly steps bar chart
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.fill").foregroundColor(.blue)
                            Text("Hourly steps")
                                .font(.headline)
                            Spacer()
                            Text("Today")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        MinimalBarChart(values: hourlySteps.map { Double($0) })
                            .frame(height: 120)
                        HStack(spacing: 0) {
                            ForEach(Array(hourlyLabels.enumerated()), id: \.offset) { _, label in
                                Text(label)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .padding(.horizontal)

                    // Activity calories line
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "flame.fill").foregroundColor(.orange)
                            Text("Activity calories")
                                .font(.headline)
                            Spacer()
                        }
                        MinimalLineChart(values: activeCalories, color: .orange)
                            .frame(height: 120)
                        HStack {
                            Text("Total active: \(Int(activeCalories.reduce(0, +))) kcal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .padding(.horizontal)

                    Spacer(minLength: 12)
                }
                .padding(.top)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBlue).opacity(0.06)]), startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Small components

private struct SummaryPill: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
        .cornerRadius(12)
    }
}

private struct MinimalBarChart: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 1)
            let barW = geo.size.width / CGFloat(max(values.count, 1))
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(values.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top))
                        .frame(width: barW - 2, height: CGFloat(values[i]) / CGFloat(maxV) * geo.size.height)
                }
            }
        }
    }
}

private struct MinimalLineChart: View {
    let values: [Double]
    var color: Color = .blue
    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let w = geo.size.width
                let h = geo.size.height
                let maxV = values.max() ?? 1
                let minV = values.min() ?? 0
                let range = max(maxV - minV, 1)
                let stepX = w / CGFloat(values.count - 1)
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = h - ((CGFloat(v - minV) / CGFloat(range)) * h)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

#Preview {
    StepsDetailView()
}
