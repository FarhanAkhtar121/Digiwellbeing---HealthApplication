import SwiftUI

/// Centralized app branding: logo and top bar used across all screens.
struct AppLogoView: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            if UIImage(named: "AppMonogram") != nil {
                Image("AppMonogram")
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback vector mark if asset not available
                ZStack {
                    LinearGradient(colors: [.blue, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .mask(
                            Image(systemName: "heart.text.square.fill")
                                .resizable()
                                .scaledToFit()
                        )
                    Color.clear
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .accessibilityLabel("App Logo")
    }
}

struct AppTopBar: View {
    var title: String = "DigitalWellbeing - Health App"
    var showLogout: Bool = false
    var onLogout: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            AppLogoView(size: 28)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if showLogout {
                Button(action: { onLogout?() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                        .foregroundColor(.red)
                        .accessibilityLabel("Logout")
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemBackground).opacity(0.95))
    }
}

#Preview {
    VStack(spacing: 0) {
        AppTopBar(showLogout: true) {}
        Spacer()
    }
}
