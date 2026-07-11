//
//  Flow_1App.swift
//  Flow_1
//
//  Created by 魏嘉賢 on 2026/6/11.
//

import SwiftUI
import ActivityKit
import GoogleMobileAds
import AppTrackingTransparency

// MARK: - App Delegate

/// 應用程式委任，負責處理生命週期事件
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Google Mobile Ads SDK 的初始化移至請求隱私權後執行
        return true
    }
    func applicationWillTerminate(_ application: UIApplication) {
        // App 被強制滑掉 (Force Quit) 時，立刻把所有的 Live Activity 殺掉，
        // 避免出現殭屍動態島
        if #available(iOS 16.2, *) {
            let group = DispatchGroup()
            group.enter()
            Task {
                for activity in Activity<FlowWidgetAttributes>.activities {
                    let finalState = FlowWidgetAttributes.ContentState(progress: 0.0, statusMessage: "Cancelled")
                    await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
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
    
    @State private var hasRequestedATT = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if !hasRequestedATT {
                    hasRequestedATT = true
                    // 延遲一點點時間等待畫面完全渲染，再跳出追蹤授權提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        ATTrackingManager.requestTrackingAuthorization { status in
                            // 無論用戶同意或拒絕，我們都在確認後才初始化廣告 SDK
                            MobileAds.shared.start(completionHandler: nil)
                        }
                    }
                }
            }
        }
    }
}
