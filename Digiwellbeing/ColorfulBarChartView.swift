import SwiftUI

struct ColorfulBarChartView: View {
    let data: [Double]
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width / CGFloat(data.count)
            let maxY = data.max() ?? 1
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<data.count, id: \.self) { i in
                    Rectangle()
                        .fill(barColor(for: data[i], max: maxY))
                        .frame(width: width - 2, height: CGFloat(data[i]) / CGFloat(maxY) * geo.size.height)
                }
            }
        }
    }
    func barColor(for value: Double, max: Double) -> LinearGradient {
        let percent = value / max
        if percent > 0.8 {
            return LinearGradient(gradient: Gradient(colors: [Color.red, Color.orange]), startPoint: .bottom, endPoint: .top)
        } else if percent > 0.6 {
            return LinearGradient(gradient: Gradient(colors: [Color.orange, Color.yellow]), startPoint: .bottom, endPoint: .top)
        } else if percent > 0.4 {
            return LinearGradient(gradient: Gradient(colors: [Color.yellow, Color.green]), startPoint: .bottom, endPoint: .top)
        } else {
            return LinearGradient(gradient: Gradient(colors: [Color.green, Color.teal]), startPoint: .bottom, endPoint: .top)
        }
    }
}
