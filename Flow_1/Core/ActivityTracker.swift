//
//  ActivityTracker.swift
//  Flow_1
//
//  Created by Libri-AI on 2026/07/08.
//

import Foundation

#if os(iOS)
import ActivityKit

actor ActivityTracker {
    private var currentActivity: Activity<FlowWidgetAttributes>? = nil
    
    init() {
        Task {
            for activity in Activity<FlowWidgetAttributes>.activities {
                let finalState = FlowWidgetAttributes.ContentState(progress: 0.0, statusMessage: "Cancelled")
                if #available(iOS 16.2, *) {
                    await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: finalState, dismissalPolicy: .immediate)
                }
            }
        }
    }
    
    func start(documentName: String) {
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = FlowWidgetAttributes(documentName: documentName)
            let initialState = FlowWidgetAttributes.ContentState(progress: 0.0, statusMessage: "Starting...")
            do {
                if #available(iOS 16.2, *) {
                    self.currentActivity = try Activity.request(attributes: attributes, content: .init(state: initialState, staleDate: nil))
                } else {
                    self.currentActivity = try Activity.request(attributes: attributes, contentState: initialState)
                }
            } catch {
                AppLogger.shared.error("Activity request failed: \(error)")
            }
        }
    }
    
    func update(progress: Double, message: String) async {
        guard let activity = currentActivity else { return }
        let currentState = FlowWidgetAttributes.ContentState(progress: progress, statusMessage: message)
        if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: currentState, staleDate: nil))
        } else {
            await activity.update(using: currentState)
        }
    }
    
    func end(progress: Double, message: String) async {
        guard let activity = currentActivity else { return }
        let finalState = FlowWidgetAttributes.ContentState(progress: progress, statusMessage: message)
        if #available(iOS 16.2, *) {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        } else {
            await activity.end(using: finalState, dismissalPolicy: .immediate)
        }
        self.currentActivity = nil
    }
}
#else
actor ActivityTracker {
    func start(documentName: String) {}
    func update(progress: Double, message: String) async {}
    func end(progress: Double, message: String) async {}
}
#endif

#if os(iOS)
import AppIntents

@available(iOS 16.1, *)
public struct CancelConversionIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Cancel Conversion"
    public static var description: IntentDescription = IntentDescription("Cancels the current PDF conversion task.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: Notification.Name("CancelConversionActivity"), object: nil)
        return .result()
    }
}
#endif
