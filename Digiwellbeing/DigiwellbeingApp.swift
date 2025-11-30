import SwiftUI

@main
struct DigiwellbeingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Dispatch to main thread explicitly
                    DispatchQueue.main.async {
                        _ = AuthManager.shared.handleOpenURL(url)
                    }
                }
        }
    }
}
