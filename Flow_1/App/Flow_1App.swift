//
//  Flow_1App.swift
//  Flow_1
//
//  Created by 魏嘉賢 on 2026/6/11.
//

import SwiftUI

@main
struct Flow_1App: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    init() {
        // 🚀 Initialize the AppLogger and setup crash handler
        _ = AppLogger.shared
        AppLogger.shared.info("Application Launched")
    }
    
    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}
