//
//  Flow_1App.swift
//  Flow_1
//
//  Created by 魏嘉賢 on 2026/6/11.
//

import SwiftUI

import ActivityKit

// MARK: - App Delegate

/// 應用程式委任，負責處理生命週期事件
class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        // App 被強制滑掉 (Force Quit) 時，立刻把所有的 Live Activity 殺掉，
        // 避免出現殭屍動態島
        let group = DispatchGroup()
        group.enter()
        Task {
            for activity in Activity<FlowWidgetAttributes>.activities {
                let finalState = FlowWidgetAttributes.ContentState(progress: 0.0, statusMessage: "Cancelled")
                if #available(iOS 16.2, *) {
                    await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: .immediate)
                }
            }
            group.leave()
        }
        // 使用 RunLoop 來等待，避免在主執行緒上造成 Deadlock 導致系統提早 Kill
        let timeout = Date(timeIntervalSinceNow: 1.5)
        while group.wait(timeout: .now()) == .timedOut && Date() < timeout {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
    }
}

// MARK: - Main App

/// 應用程式進入點
@main
struct Flow_1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
