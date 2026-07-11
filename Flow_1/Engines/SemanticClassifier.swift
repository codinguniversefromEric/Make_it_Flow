//
//  SemanticClassifier.swift
//  Flow_1
//
//  Created by Libri-AI Engine.
//

import Foundation
import CoreGraphics

// MARK: - 語意分類器：基於評分累計與 sigmoid 信心度的多特徵分類

/// 負責將段落區塊分類為不同的語意角色
enum SemanticClassifier {

    // MARK: - Cached Regex Patterns
    private static let numberedListPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^\\d{1,3}[.)]\\s"),
        try! NSRegularExpression(pattern: "^[a-zA-Z][.)]\\s"),
        try! NSRegularExpression(pattern: "^[ivxIVX]+[.)]\\s")
    ]
    
    private static let chapterPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^chapter\\s+\\d+", options: .caseInsensitive),
        try! NSRegularExpression(pattern: "^part\\s+\\w+", options: .caseInsensitive),
        try! NSRegularExpression(pattern: "^第[一二三四五六七八九十百零0-9]+[章節]"),
        try! NSRegularExpression(pattern: "^appendix", options: .caseInsensitive)
    ]

    // MARK: - 主分類入口

    /// 對段落區塊陣列進行語意分類
    /// - Parameters:
    ///   - blocks: 待分類的段落區塊 (應已由 LayoutEngine 聚合)
    ///   - pageHeight: 頁面高度 (顯示座標系)
    ///   - styleRegistry: 全域文件樣式基準
    static func classify(blocks: inout [ParagraphBlock], pageHeight: CGFloat, styleRegistry: StyleRegistry) {
        for i in 0..<blocks.count {
            blocks[i].role = classifyBlock(
                blocks[i],
                styleRegistry: styleRegistry,
                pageHeight: pageHeight
            )
        }
    }

    // MARK: - 單區塊分類

    /// 根據多特徵評分規則分類單一區塊
    private static func classifyBlock(
        _ block: ParagraphBlock,
        styleRegistry: StyleRegistry,
        pageHeight: CGFloat
    ) -> SemanticRole {
        let sizeRatio = block.dominantFontSize / styleRegistry.bodyFontSize
        let boldRatio = block.boldRatio
        let normY = block.normalizedY(pageHeight: pageHeight)
        let charCount = block.unifiedText.count
        let text = block.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // === 階段 1：絕對規則過濾 (高信心度快速路徑) ===

        // 🔒 頁碼偵測
        if charCount < 8 && isHighlyNumeric(text) && (normY < 0.05 || normY > 0.95) {
            return .pageNumber
        }

        // 🔒 頁眉偵測
        if normY < 0.08 && sizeRatio <= 1.0 && charCount < 80 {
            return .pageHeader
        }

        // 🔒 頁腳偵測
        if normY > 0.92 && sizeRatio <= 1.0 && charCount < 80 {
            return .pageFooter
        }

        // 📝 列表項目
        if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("–") ||
           text.hasPrefix("▪") || matchesNumberedList(text) {
            return .listItem
        }

        // 🔬 頁尾註
        if sizeRatio < 0.85 && normY > 0.85 && charCount < 300 {
            return .footnote
        }

        // 🖼️ 圖表說明
        if sizeRatio < 0.88 && charCount < 120 && (text.lowercased().hasPrefix("figure") || text.lowercased().hasPrefix("table") || text.hasPrefix("圖") || text.hasPrefix("表")) {
            return .caption
        }

        // === 階段 2：專家評分系統 (針對標題與內文的模糊地帶) ===
        
        var score: CGFloat = 0.0
        
        // 1. Regex 章節關鍵字匹配 (+8)
        if matchesChapter(text) {
            score += 8.0
        }
        
        // 2. 字型大小相似度評分 (與全域 H1/H2 比較)
        let h1Diff = abs(block.dominantFontSize - styleRegistry.h1FontSize)
        let h2Diff = abs(block.dominantFontSize - styleRegistry.h2FontSize)
        
        if h1Diff < 1.0 {
            score += 8.0
        } else if h2Diff < 1.0 {
            score += 5.0
        }
        
        // 3. 相對字型比例加分 (+0 ~ +10)
        if sizeRatio > 1.0 {
            let ratioBonus = min((sizeRatio - 1.0) * 15.0, 10.0)
            score += ratioBonus
        }
        
        // 4. 粗體加分 (+2)
        if boldRatio > 0.5 {
            score += 2.0
        }
        
        // 5. 幾何長度懲罰
        if charCount > 120 {
            score -= 10.0
        } else if charCount > 80 {
            score -= 5.0
        } else if charCount < 40 {
            score += 2.0 // 短句子更可能是標題
        }

        // === 階段 3：Sigmoid 信心度與層級判定 ===
        // 我們用 sigmoid 轉換分數，並設定門檻：
        // H1 門檻: >= 12.0
        // H2 門檻: >= 8.0
        // H3 (預設 heading) 門檻: >= 5.0
        
        if score >= 12.0 {
            return .title // 最高層級標題
        } else if score >= 5.0 {
            return .heading // 次級標題 (H2/H3 合併為 heading)
        }
        
        // 預設：內文
        return .body
    }

    // MARK: - 輔助判斷

    /// 判斷文字是否主要由數字組成
    private static func isHighlyNumeric(_ text: String) -> Bool {
        let digits = text.filter { $0.isNumber }
        let nonSpace = text.filter { !$0.isWhitespace }
        guard !nonSpace.isEmpty else { return false }
        return CGFloat(digits.count) / CGFloat(nonSpace.count) > 0.5
    }

    /// 判斷是否符合列表編號格式
    private static func matchesNumberedList(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        for regex in numberedListPatterns {
            if regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }
    
    /// 判斷是否為章節標題關鍵字
    private static func matchesChapter(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        for regex in chapterPatterns {
            if regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - 工具

    /// 判斷該角色區塊是否應在最終輸出被捨棄
    static func shouldDrop(_ role: SemanticRole) -> Bool {
        switch role {
        case .pageHeader, .pageFooter, .pageNumber:
            return true
        default:
            return false
        }
    }

    /// 將段落區塊轉換為對應的 Markdown 格式
    static func toMarkdown(block: ParagraphBlock) -> String {
        let text = block.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        switch block.role {
        case .title:
            return "# \(text)\n\n"
        case .heading:
            return "### \(text)\n\n" // 可視需要擴充為 ## 和 ###
        case .body:
            return "\(text)\n\n"
        case .listItem:
            return "- \(text)\n"
        case .footnote:
            return "> *\(text)*\n\n"
        case .caption:
            return "*\(text)*\n\n"
        case .formula:
            return "$$ \(text) $$\n\n"
        case .pageHeader, .pageFooter, .pageNumber:
            return "" 
        case .table, .picture:
            return ""
        }
    }
}
