//
//  LLMEngine.swift
//  Flow_1
//
//  Created by 魏嘉賢 on 2026/6/13.
//  Rewritten for fully on-device processing on 2026/6/15.
//

import Foundation
import Combine

// 條件引入：只在支援的 SDK 上才引入 FoundationModels
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 全端點 LLM 語意修復引擎

class LLMEngine: ObservableObject {
    static let shared = LLMEngine()
    
    // MARK: - Cached Regex Patterns
    private nonisolated(unsafe) static let multiSpaceRegex = try! NSRegularExpression(pattern: " {2,}")
    private nonisolated(unsafe) static let multiNewlineRegex = try! NSRegularExpression(pattern: "\n{3,}")
    private nonisolated(unsafe) static let numberedLineRegex = try! NSRegularExpression(pattern: "^\\d+[.)]\\s")

    @Published var isModelLoaded = false
    @Published var isProcessing = false
    @Published var statusMessage = "等待初始化..."
    @Published var downloadProgress: Double = 0.0

    /// 是否有 Apple Intelligence 可用 (runtime 檢測結果)
    private var hasFoundationModels = false

    private init() {
        initializeEngine()
    }

    // MARK: - 初始化

    @MainActor
    func prepareModel() async {
        initializeEngine()
    }

    private func initializeEngine() {
        #if canImport(FoundationModels)
        // SDK 有 FoundationModels → 嘗試檢查 runtime 可用性
        if #available(iOS 26, *) {
            Task { @MainActor in
                let model = SystemLanguageModel.default
                if model.availability == .available {
                    self.hasFoundationModels = true
                    self.isModelLoaded = true
                    self.statusMessage = "Apple Intelligence 已就緒 (on-device)"
                    self.downloadProgress = 1.0
                    print("✅ Apple Intelligence 已就緒")
                } else {
                    print("⚠️ Apple Intelligence 不可用，回退原生引擎")
                    self.activateNativeEngine()
                }
            }
        } else {
            activateNativeEngine()
        }
        #else
        // SDK 沒有 FoundationModels → 直接啟用原生引擎
        activateNativeEngine()
        #endif
    }

    private func activateNativeEngine() {
        DispatchQueue.main.async {
            self.hasFoundationModels = false
            self.isModelLoaded = true  // 純規則引擎永遠就緒
            self.statusMessage = "原生修復引擎已就緒"
            self.downloadProgress = 1.0
            print("✅ 原生規則引擎已啟用")
        }
    }

    // MARK: - 核心功能：語意修復

    @MainActor
    func refineMarkdown(rawText: String) async -> String {
        self.isProcessing = true
        self.statusMessage = "正在修復文字..."

        let result: String
        let engineName: String

        #if canImport(FoundationModels)
        if hasFoundationModels {
            engineName = "Apple Intelligence"
            print("🧠 LLM 引擎: 使用 Apple Intelligence (輸入 \(rawText.count) 字元)")
            result = await refineWithFoundationModels(rawText)
        } else {
            engineName = "原生規則引擎"
            print("⚡️ LLM 引擎: 使用原生規則引擎 (輸入 \(rawText.count) 字元)")
            result = await Task.detached(priority: .userInitiated) { [self] in
                return self.cleanTextNatively(rawText)
            }.value
        }
        #else
        engineName = "原生規則引擎"
        print("⚡️ LLM 引擎: 使用原生規則引擎 (輸入 \(rawText.count) 字元)")
        result = await Task.detached(priority: .userInitiated) { [self] in
            return self.cleanTextNatively(rawText)
        }.value
        #endif

        print("✅ LLM 引擎: \(engineName) 完成 (輸出 \(result.count) 字元)")
        self.statusMessage = hasFoundationModels ? "Apple Intelligence 已就緒 (on-device)" : "原生修復引擎已就緒"
        self.isProcessing = false
        return result
    }

    // MARK: - 路線 A: Apple Foundation Models (iOS 26+)

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func refineWithFoundationModels(_ rawText: String) async -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            return await Task.detached(priority: .userInitiated) { [self] in
                return self.cleanTextNatively(rawText)
            }.value
        }

        let session = LanguageModelSession(model: model)

        let prompt = """
        You are a STRICT OCR text restoration engine. Fix ONLY these issues:
        1. Merge hyphenated words split across lines (e.g., "hyper-\\ndontia" → "hyperdontia")
        2. Fix broken sentences from column splits
        3. Recover mathematical symbols into LaTeX notation

        ABSOLUTE RULES:
        - Output the EXACT original text length. Do NOT summarize.
        - Do NOT rewrite, paraphrase, or "improve" the text.
        - If text cuts off abruptly, leave it cut off.
        - Output ONLY the restored text. No chat, no notes.

        --- TEXT BEGIN ---
        \(rawText)
        --- TEXT END ---
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            print("⚠️ Foundation Models 呼叫失敗，回退原生引擎: \(error)")
            return await Task.detached(priority: .userInitiated) { [self] in
                return self.cleanTextNatively(rawText)
            }.value
        }
    }
    #endif

    // MARK: - 路線 B: 原生規則引擎 (所有 iOS 版本)

    /// ⚡️ Markdown-safe 純規則修復引擎：0 幻覺、毫秒級完成、100% 忠於原文
    /// 注意：輸入已經是格式化的 Markdown，必須保護所有結構標記
    nonisolated func cleanTextNatively(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 保留空行 (Markdown 段落分隔符)
            if trimmed.isEmpty {
                result.append("")
                i += 1
                continue
            }
            
            // 保護 Markdown 結構標記：不做任何修改
            if isMarkdownStructural(trimmed) {
                result.append(trimmed)
                i += 1
                continue
            }
            
            // 一般內文：執行安全修復
            var cleaned = trimmed
            
            // 收斂多餘的連續空白
            cleaned = Self.multiSpaceRegex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: " ")
            
            // 跨行斷字修復：僅當本行以 "-" 結尾且下一行是普通文字時才合併
            if cleaned.hasSuffix("-") && i + 1 < lines.count {
                let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if !nextTrimmed.isEmpty && !isMarkdownStructural(nextTrimmed) {
                    // 移除尾部連字號，接上下一行
                    cleaned = String(cleaned.dropLast()) + nextTrimmed
                    i += 2  // 跳過已合併的下一行
                    result.append(cleaned)
                    continue
                }
            }
            
            result.append(cleaned)
            i += 1
        }
        
        // 最終清理：收斂 3+ 連續空行 → 最多 2 個
        var finalResult = result.joined(separator: "\n")
        finalResult = Self.multiNewlineRegex.stringByReplacingMatches(in: finalResult, range: NSRange(finalResult.startIndex..., in: finalResult), withTemplate: "\n\n")
        
        return finalResult
    }
    
    /// 判斷一行是否為 Markdown 結構標記 (必須保護，不可修改或合併)
    nonisolated private func isMarkdownStructural(_ line: String) -> Bool {
        // 標題
        if line.hasPrefix("#") { return true }
        // 列表項目
        if line.hasPrefix("- ") || line.hasPrefix("* ") { return true }
        // 編號列表
        if let first = line.first, first.isNumber,
           Self.numberedLineRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil { return true }
        // 引用區塊
        if line.hasPrefix(">") { return true }
        // 公式
        if line.hasPrefix("$$") { return true }
        // 圖片
        if line.hasPrefix("![") { return true }
        // 斜體 caption
        if line.hasPrefix("*") && line.hasSuffix("*") { return true }
        // 水平線
        if line == "---" || line == "***" || line == "___" { return true }
        return false
    }
}
