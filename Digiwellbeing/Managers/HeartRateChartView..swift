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
                .padding(.horizontal)
            
            if readings.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 200)
                    .overlay {
                        Text("No heart rate data available")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
            } else {
                Chart(readings.suffix(20)) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("BPM", reading.heartRate)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.red.gradient)
                }
                .frame(height: 200)
                .padding()
            }
        }
    }
}

