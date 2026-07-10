//
//  AppSettings.swift
//  Flow_1
//
//  Persistent user preferences via UserDefaults.
//

import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Persisted Keys
    private enum Keys {
        static let selectedModel = "selectedVisionModel"
        static let useAI = "useAIRefinement"
        static let debugMode = "debugModeEnabled"
    }
    
    // MARK: - Published Properties
    
    /// 選擇的視覺模型 (預設 Auto)
    @Published var selectedModel: VisionModelType {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: Keys.selectedModel)
            LayoutVisionManager.shared.setupEngine()
        }
    }
    
    /// 是否啟用 AI 語意修復
    @Published var useAI: Bool {
        didSet { UserDefaults.standard.set(useAI, forKey: Keys.useAI) }
    }
    
    /// 是否啟用 Debug 模式 (顯示 YOLO 框 + 語意標記)
    @Published var debugMode: Bool {
        didSet { UserDefaults.standard.set(debugMode, forKey: Keys.debugMode) }
    }
    
    private init() {
        let savedModelRaw = UserDefaults.standard.string(forKey: Keys.selectedModel) ?? VisionModelType.auto.rawValue
        self.selectedModel = VisionModelType(rawValue: savedModelRaw) ?? .auto
        
        self.useAI = UserDefaults.standard.object(forKey: Keys.useAI) as? Bool ?? true
        self.debugMode = UserDefaults.standard.object(forKey: Keys.debugMode) as? Bool ?? false
    }
}
