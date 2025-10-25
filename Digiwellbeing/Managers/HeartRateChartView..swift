//
//  HeartRateChartView..swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 18/09/25.
//
import SwiftUI
import Charts

struct HeartRateChartView: View {
    let readings: [HeartRateReading]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Heart Rate History")
                .font(.headline)
                .padding(.bottom, 4)
            if readings.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 120)
                    Text("No heart rate data available")
                        .foregroundColor(.gray)
                }
            } else {
                Chart(readings) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("BPM", reading.heartRate)
                    )
                }
                .frame(height: 120)
            }
        }
        .padding(.horizontal)
    }
}
