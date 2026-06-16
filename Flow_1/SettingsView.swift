//
//  SettingsView.swift
//  Flow_1
//
//  Production settings panel — all debug & engine controls live here.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var llmEngine = LLMEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - AI 引擎
                Section {
                    HStack {
                        Label("Semantic Engine", systemImage: "brain.head.profile")
                        Spacer()
                        Text(llmEngine.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Toggle(isOn: $settings.useAI) {
                        Label("Enable AI Enhancement", systemImage: "wand.and.stars")
                    }
                    .tint(.purple)
                    .accessibilityLabel("AI Enhancement")
                    .accessibilityHint("Toggle neural engine text refinement")
                } header: {
                    Text("INTELLIGENCE")
                } footer: {
                    Text("When enabled, the neural engine refines extracted text for flawless semantic flow and continuity.")
                }
                
                // MARK: - 視覺模型
                Section {
                    Picker(selection: $settings.selectedModel) {
                        ForEach(VisionModelType.allCases) { model in
                            Text(model.rawValue).tag(model)
                        }
                    } label: {
                        Label("Vision Architecture", systemImage: "eye.trianglebadge.exclamationmark")
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("VISION")
                } footer: {
                    Text("Select the underlying YOLO architecture. Heavier models offer superior precision at the cost of processing speed.")
                }
                
                // MARK: - 開發者
                Section {
                    Toggle(isOn: $settings.debugMode) {
                        Label("Developer Diagnostics", systemImage: "ladybug")
                    }
                    .tint(.orange)
                    .accessibilityLabel("Developer Diagnostics")
                    .accessibilityHint("Toggle visual diagnostic overlays showing YOLO bounding boxes")
                    
                    NavigationLink(destination: LogViewerView()) {
                        Label("View App Logs", systemImage: "scroll")
                    }
                } header: {
                    Text("DEVELOPER")
                } footer: {
                    Text("Enables visual diagnostic overlays, rendering YOLO bounding boxes and semantic classifications directly on the document.")
                }
                
                // MARK: - 關於
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Core Engine", systemImage: "gearshape.2")
                        Spacer()
                        Text("Libri-AI Hybrid")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("ABOUT")
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
