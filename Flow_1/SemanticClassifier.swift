//
//  SemanticClassifier.swift
//  Flow_1
//
//  Created by Libri-AI Engine on 2026/6/14.
//

import Foundation
import CoreGraphics

// MARK: - 語意分類器：基於字體大小比、粗體比、位置的多特徵啟發式分類

enum SemanticClassifier {

    // MARK: - Cached Regex Patterns
    private static let numberedListPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "^\\d{1,3}[.)]\\s"),
        try! NSRegularExpression(pattern: "^[a-zA-Z][.)]\\s"),
        try! NSRegularExpression(pattern: "^[ivxIVX]+[.)]\\s")
    ]

    // MARK: - 主分類入口

    /// 對段落區塊陣列進行語意分類
    /// - Parameters:
    ///   - blocks: 待分類的段落區塊 (應已由 LayoutEngine 聚合)
    ///   - pageHeight: 頁面高度 (顯示座標系)
    /// - Returns: 分類完成的段落區塊陣列
    static func classify(blocks: inout [ParagraphBlock], pageHeight: CGFloat) {
        // 1. 偵測 body 字體大小 (取所有區塊中出現最頻繁的 dominantFontSize)
        let bodyFontSize = detectBodyFontSize(blocks: blocks)
        guard bodyFontSize > 0 else { return }

        // 2. 逐一分類
        for i in 0..<blocks.count {
            blocks[i].role = classifyBlock(
                blocks[i],
                bodyFontSize: bodyFontSize,
                pageHeight: pageHeight
            )
        }
    }

    // MARK: - 單區塊分類

    /// 根據多特徵啟發式規則分類單一區塊
    private static func classifyBlock(
        _ block: ParagraphBlock,
        bodyFontSize: CGFloat,
        pageHeight: CGFloat
    ) -> SemanticRole {
        let sizeRatio = block.dominantFontSize / bodyFontSize
        let boldRatio = block.boldRatio
        let normY = block.normalizedY(pageHeight: pageHeight)
        let charCount = block.unifiedText.count
        let text = block.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // === 安全防護：先排除頁面假象 ===

        // 🔒 頁碼偵測：極短、高度數字化、位於極端邊緣
        if charCount < 8 && isHighlyNumeric(text) && (normY < 0.05 || normY > 0.95) {
            return .pageNumber
        }

        // 🔒 頁眉偵測：頁面極上方 + 字體不大 + 短文字
        if normY < 0.08 && sizeRatio <= 1.0 && charCount < 80 {
            return .pageHeader
        }

        // 🔒 頁腳偵測：頁面極下方 + 字體不大 + 短文字
        if normY > 0.92 && sizeRatio <= 1.0 && charCount < 80 {
            return .pageFooter
        }

        // === 正向分類 ===

        // 📖 文件標題：字體 ≥ 1.6× body，粗體比高，位於頁面上方 1/3
        if sizeRatio >= 1.6 && boldRatio > 0.5 && normY < 0.35 {
            return .title
        }

        // 📑 章節標題：放寬條件 (1.2倍大 / 純粗體短句 / Chapter關鍵字)
        let isShortBold = (sizeRatio >= 1.0 && boldRatio > 0.8 && charCount < 100)
        let lowerText = text.lowercased()
        let hasChapterKeyword = lowerText.hasPrefix("chapter ") || lowerText.hasPrefix("part ") || (text.hasPrefix("第") && (text.contains("章") || text.contains("節")))
        
        if (sizeRatio >= 1.2 && boldRatio > 0.3) || isShortBold || hasChapterKeyword {
            return .heading
        }

        // 📝 列表項目：以常見列表符號開頭
        if text.hasPrefix("•") || text.hasPrefix("-") || text.hasPrefix("–") ||
           text.hasPrefix("▪") || matchesNumberedList(text) {
            return .listItem
        }

        // 🔬 頁尾註：字體小 + 頁面下方 + 短文字
        if sizeRatio < 0.85 && normY > 0.85 && charCount < 300 {
            return .footnote
        }

        // 🖼️ 圖表說明：字體稍小 + 極短
        if sizeRatio < 0.88 && charCount < 120 {
            return .caption
        }

        // 📄 預設：內文
        return .body
    }

    // MARK: - Body 字體偵測

    /// 偵測文件的「內文字體大小」= 所有區塊中出現最頻繁的 dominantFontSize
    private static func detectBodyFontSize(blocks: [ParagraphBlock]) -> CGFloat {
        let allSizes = blocks.map { round($0.dominantFontSize * 10) / 10 }
        guard !allSizes.isEmpty else { return 12.0 }

        let counts = Dictionary(grouping: allSizes, by: { $0 })
        let mostCommon = counts.max(by: { $0.value.count < $1.value.count })
        return mostCommon?.key ?? 12.0
    }

    // MARK: - 輔助判斷

    /// 檢查文字是否高度數字化 (頁碼判斷用)
    private static func isHighlyNumeric(_ text: String) -> Bool {
        let digits = text.filter { $0.isNumber }
        let nonSpace = text.filter { !$0.isWhitespace }
        guard !nonSpace.isEmpty else { return false }
        return CGFloat(digits.count) / CGFloat(nonSpace.count) > 0.5
    }

    /// 檢查是否為編號列表 (e.g., "1.", "2)", "a.", "i.")
    private static func matchesNumberedList(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        for regex in numberedListPatterns {
            if regex.firstMatch(in: text, range: range) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - 工具：判斷哪些角色應該被丟棄

    /// 這些語意角色應該從最終輸出中移除
    static func shouldDrop(_ role: SemanticRole) -> Bool {
        switch role {
        case .pageHeader, .pageFooter, .pageNumber:
            return true
        default:
            return false
        }
    }

    /// 將語意角色轉換為 Markdown 格式
    static func toMarkdown(block: ParagraphBlock) -> String {
        let text = block.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        switch block.role {
        case .title:
            return "# \(text)\n\n"
        case .heading:
            return "### \(text)\n\n"
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
            return ""  // 丟棄
        case .table, .picture:
            return ""  // 由圖片裁切通道處理
        }
    }
}
