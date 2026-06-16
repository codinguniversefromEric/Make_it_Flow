//
//  LogViewerView.swift
//  Flow_1
//
//  Created by AI on 2026/6/15.
//

import SwiftUI

struct LogViewerView: View {
    @State private var logContent: String = "載入中..."
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(logContent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            HStack {
                Button(action: {
                    UIPasteboard.general.string = logContent
                }) {
                    Label("複製全部", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy all logs")
                .accessibilityHint("Copy entire log content to clipboard")
                
                Spacer()
                
                Button(role: .destructive, action: {
                    AppLogger.shared.clearLogs()
                    loadLogs()
                }) {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Clear logs")
                .accessibilityHint("Delete all log entries")
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("系統日誌 (AppLog)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadLogs()
        }
    }
    
    private func loadLogs() {
        if let url = AppLogger.shared.logFileURL,
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            logContent = text.isEmpty ? "日誌目前是空的。" : text
        } else {
            logContent = "無法讀取日誌，或檔案尚未建立。"
        }
    }
}

#Preview {
    NavigationView {
        LogViewerView()
    }
}
