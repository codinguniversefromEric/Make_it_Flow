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
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Premium
                Section {
                    if subscriptionManager.isPremium {
                        HStack {
                            Label("Flow Premium", systemImage: "star")
                                .foregroundColor(.accentColor)
                            Spacer()
                            Text("Active")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("remove ads", systemImage: "eraser")
                                .foregroundColor(.accentColor)
                                .font(.headline)
                        }
                    }
                }
                
                // MARK: - AI 引擎
                if llmEngine.isAIAvailable {
                    Section {
//                        HStack {
//                            Label("Engine", systemImage: "doc.text.fill.viewfinder")
//                            Spacer()
//                            Text(llmEngine.statusMessage)
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                        }
                        
                        Toggle(isOn: $settings.useAI) {
                            Label("AI Enhance", systemImage: "apple.intelligence")
                        }
                        .accessibilityLabel("AI Enhancement")
                    } header: {
                        Text("APPLE INTELLIGENCE")
                    } footer: {
                        Text("When enabled, AI refines content.")
                    }
                }
                
                // MARK: - 開發者與視覺模型 (合併)
                if AppSettings.showDeveloperSettings {
                    Section {
                        // Vision 部分
                        Picker(selection: $settings.selectedModel) {
                            ForEach(VisionModelType.allCases) { model in
                                Text(model.rawValue).tag(model)
                            }
                        } label: {
                            Label("Vision Architecture", systemImage: "eye.trianglebadge.exclamationmark")
                        }
                        .pickerStyle(.navigationLink)
                        
                        if settings.selectedModel != .auto {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Manual override is active. Automatic OOM memory protection may be bypassed.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Current: \(LayoutVisionManager.shared.currentParserName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // 開發者部分
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
                        Text("DEVELOPER & VISION")
                    } footer: {
                        Text("Select Auto to dynamically choose the best engine based on device memory. Developer diagnostics enable visual overlays rendering YOLO bounding boxes directly on the document.")
                    }
                }
                
                // MARK: - 關於
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/codinguniversefromEric/Make_it_Flow.git")!) {
                        HStack {
                            Label("Open Source & Licenses", systemImage: "link")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(subscriptionManager)
            }
        }
    }
}
