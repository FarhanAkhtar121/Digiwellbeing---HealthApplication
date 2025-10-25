//
//  DigiwellbeingApp.swift
//  Digiwellbeing
//
//  Created by farhan akhtar on 18/09/25.
//

import SwiftUI

@main
struct DigiwellbeingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = AuthManager.shared.handleOpenURL(url)
                }
        }
    }
}
