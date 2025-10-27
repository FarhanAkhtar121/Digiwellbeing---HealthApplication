import SwiftUI

struct SplashView: View {
    let appName: String
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                AppLogoView(size: 84)
                Text(appName)
                    .font(.title2).bold()
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    SplashView(appName: "DigitalWellbeing - Health App")
}
