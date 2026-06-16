//
//  LayoutEngine.swift
//  Flow_1
//
//  Created by Libri-AI Engine on 2026/6/14.
//

import Foundation
import CoreGraphics

// MARK: - 佈局分析引擎：欄位偵測 + 段落重組 + 斷字修復

enum LayoutEngine {

    // MARK: - Cached Regex Patterns
    private static let eqRegex = try! NSRegularExpression(pattern: "(?i)(Accuracy|Precision|Sensitivity|score|Recall|Specificity)\\s*\u{FFFD}\\s*")
    private static let mulRegex = try! NSRegularExpression(pattern: "([0-9A-Za-z])\\s*\u{FFFD}\\s*([0-9A-Za-z])")

    // MARK: - 1. 水平密度直方圖 → 欄位偵測

    /// 從文字碎片的水平分佈偵測欄位邊界
    /// - Parameters:
    ///   - fragments: 頁面上所有的文字碎片
    ///   - pageWidth: 頁面寬度 (顯示座標系)
    /// - Returns: 偵測到的欄位區域陣列 (從左到右排序)
    static func detectColumns(fragments: [TextFragment], pageWidth: CGFloat, pageHeight: CGFloat) -> [ColumnRegion] {
        guard !fragments.isEmpty, pageWidth > 0 else {
            return [ColumnRegion(xRange: 0...pageWidth, fragments: fragments)]
        }

        // 1. 建立 100 格的水平密度直方圖
        let bucketCount = 100
        let bucketWidth = pageWidth / CGFloat(bucketCount)
        var histogram = [Int](repeating: 0, count: bucketCount)

        for frag in fragments {

            let startBucket = max(0, Int(frag.bounds.minX / bucketWidth))
            let endBucket = min(bucketCount - 1, Int(frag.bounds.maxX / bucketWidth))
            for b in startBucket...endBucket {
                histogram[b] += 1
            }
        }

        // 2. 自適應閾值 = 總碎片數 / (格數 × 2)
        let threshold = max(1, fragments.count / (bucketCount * 2))

        // 3. 在中間 80% 區域搜尋連續空隙 (排除邊距)
        let marginBuckets = bucketCount / 10  // 10% 左右邊距
        let scanStart = marginBuckets
        let scanEnd = bucketCount - marginBuckets

        // 找出所有「稀疏區段」(密度低於閾值的連續 buckets)
        var gaps: [(start: Int, end: Int)] = []
        var gapStart: Int? = nil

        for b in scanStart..<scanEnd {
            if histogram[b] < threshold {
                if gapStart == nil { gapStart = b }
            } else {
                if let start = gapStart {
                    gaps.append((start: start, end: b - 1))
                    gapStart = nil
                }
            }
        }
        if let start = gapStart {
            gaps.append((start: start, end: scanEnd - 1))
        }

        // 4. 篩選有效間隙：寬度必須 > 頁寬的 3%
        let minGapBuckets = max(3, Int(Double(bucketCount) * 0.03))
        let significantGaps = gaps.filter { ($0.end - $0.start + 1) >= minGapBuckets }

        // 5. 如果沒有顯著間隙 → 單欄
        guard !significantGaps.isEmpty else {
            return [ColumnRegion(xRange: 0...pageWidth, fragments: fragments)]
        }

        // 6. 根據間隙切割欄位
        var columnBoundaries: [CGFloat] = [0]
        for gap in significantGaps {
            let gapCenter = (CGFloat(gap.start) + CGFloat(gap.end)) / 2.0 * bucketWidth
            columnBoundaries.append(gapCenter)
        }
        columnBoundaries.append(pageWidth)

        // 7. 將碎片分配到各欄位
        var columns: [ColumnRegion] = []
        for i in 0..<(columnBoundaries.count - 1) {
            let xMin = columnBoundaries[i]
            let xMax = columnBoundaries[i + 1]
            let columnFrags = fragments.filter { frag in
                let fragCenter = frag.bounds.midX
                return fragCenter >= xMin && fragCenter < xMax
            }
            if !columnFrags.isEmpty {
                columns.append(ColumnRegion(xRange: xMin...xMax, fragments: columnFrags))
            }
        }

        // 防禦：如果分配後全空，回退單欄
        if columns.isEmpty {
            return [ColumnRegion(xRange: 0...pageWidth, fragments: fragments)]
        }

        return columns
    }

    // MARK: - 2. 中位數間距分析 → 段落重組

    /// 在單欄內，根據行間距的中位數將文字碎片重組為段落
    /// - Parameters:
    ///   - fragments: 單欄內的碎片 (應已按 Y 座標排序)
    ///   - pageHeight: 頁面高度
    /// - Returns: 聚合後的段落區塊陣列
    static func groupIntoParagraphs(fragments: [TextFragment], pageHeight: CGFloat) -> [ParagraphBlock] {
        guard !fragments.isEmpty else { return [] }

        // 先按 Y 座標排序 (顯示座標系，Y 越小越上方)
        let sorted = fragments.sorted { $0.bounds.minY < $1.bounds.minY }

        // 1. 計算相鄰行之間的垂直間距
        var gaps: [CGFloat] = []
        for i in 1..<sorted.count {
            let gap = sorted[i].bounds.minY - sorted[i - 1].bounds.maxY
            if gap > 0 && gap < sorted[i].bounds.height * 3 {  // 過濾極端值
                gaps.append(gap)
            }
        }

        // 2. 找中位數間距
        let medianGap: CGFloat
        if gaps.isEmpty {
            medianGap = sorted[0].bounds.height * 0.3  // 預設為字高的 30%
        } else {
            let sortedGaps = gaps.sorted()
            medianGap = sortedGaps[sortedGaps.count / 2]
        }

        // 3. 掃描並分組
        let paragraphBreakThreshold = medianGap * 1.8
        var blocks: [ParagraphBlock] = []
        var currentFrags: [TextFragment] = [sorted[0]]

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            let gap = curr.bounds.minY - prev.bounds.maxY

            // 判斷是否需要斷開新段落
            var shouldBreak = false

            // 條件 1：間距超過 1.8 倍中位數
            if gap > paragraphBreakThreshold {
                shouldBreak = true
            }

            // 條件 1.5：首行縮排 (X 座標向右縮進超過 1.5 倍字體大小)
            let xOffset = curr.bounds.minX - prev.bounds.minX
            if gap >= 0 && xOffset > (curr.fontSize * 1.5) {
                shouldBreak = true
            }

            // 條件 2：字體大小變化超過 30%
            let prevSize = prev.fontSize
            let currSize = curr.fontSize
            if prevSize > 0 && currSize > 0 {
                let sizeRatio = max(prevSize, currSize) / min(prevSize, currSize)
                if sizeRatio > 1.3 {
                    shouldBreak = true
                }
            }

            // 條件 3：粗體狀態變化 + 輕微大小變化 (標題轉換)
            if prev.isBold != curr.isBold && prevSize > 0 && currSize > 0 {
                let sizeRatio = max(prevSize, currSize) / min(prevSize, currSize)
                if sizeRatio > 1.15 {
                    shouldBreak = true
                }
            }

            if shouldBreak {
                // 完成當前段落
                blocks.append(buildParagraphBlock(from: currentFrags))
                currentFrags = [curr]
            } else {
                currentFrags.append(curr)
            }
        }

        // 收尾：最後一組
        if !currentFrags.isEmpty {
            blocks.append(buildParagraphBlock(from: currentFrags))
        }

        return blocks
    }

    // MARK: - 3. 智慧斷字修復

    /// 修復跨行斷字 (e.g., "hyperdon-" + "tia" → "hyperdontia")
    static func recoverHyphenation(lines: [String]) -> String {
        var parts: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let lastPart = parts.last, lastPart.hasSuffix("-"),
               let lastChar = lastPart.dropLast().last, lastChar.isLetter {
                // 發現斷字：移除末尾連字號，直接拼接下一行的第一個詞
                parts[parts.count - 1] = String(lastPart.dropLast()) + trimmed
            } else {
                parts.append(trimmed)
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - 4. 頁面級完整處理流程

    /// 對整個頁面的文字碎片進行完整的佈局分析
    /// - Parameters:
    ///   - fragments: 頁面上所有的文字碎片
    ///   - pageWidth: 頁面寬度
    ///   - pageHeight: 頁面高度
    /// - Returns: 依閱讀順序排列的段落區塊陣列
    static func processPage(
        fragments: [TextFragment],
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> [ParagraphBlock] {
        let fullWidthThreshold = pageWidth * 0.6
        var fullWidthFrags: [TextFragment] = []
        var normalFrags: [TextFragment] = []
        
        for frag in fragments {
            if frag.bounds.width > fullWidthThreshold {
                fullWidthFrags.append(frag)
            } else {
                normalFrags.append(frag)
            }
        }
        
        // 1. 將全寬元素聚合成區塊 (如大標題、跨欄圖表)，並按垂直位置排序
        let fullWidthBlocks = groupIntoParagraphs(fragments: fullWidthFrags, pageHeight: pageHeight)
            .sorted { $0.bounds.midY < $1.bounds.midY }
            
        // 2. 建立水平分割點 (使用每個全寬區塊的 midY 作為分界)
        let dividers = fullWidthBlocks.map { $0.bounds.midY }
        
        var allBlocks: [ParagraphBlock] = []
        
        // 3. 針對每個被全寬元素切分出來的水平區間 (共有 dividers.count + 1 個區間)
        for i in 0...dividers.count {
            let minY = (i == 0) ? -CGFloat.greatestFiniteMagnitude : dividers[i - 1]
            let maxY = (i == dividers.count) ? CGFloat.greatestFiniteMagnitude : dividers[i]
            
            // 取出落在此區間的正常碎片
            let regionFrags = normalFrags.filter { frag in
                let y = frag.bounds.midY
                return y >= minY && y < maxY
            }
            
            if !regionFrags.isEmpty {
                // 對此區間內的碎片進行分欄與段落重組
                let columns = detectColumns(fragments: regionFrags, pageWidth: pageWidth, pageHeight: pageHeight)
                for column in columns {
                    let paragraphs = groupIntoParagraphs(fragments: column.fragments, pageHeight: pageHeight)
                    allBlocks.append(contentsOf: paragraphs)
                }
            }
            
            // 區間處理結束後，接上對應的那個全寬區塊 (維持正確的閱讀順序)
            if i < fullWidthBlocks.count {
                allBlocks.append(fullWidthBlocks[i])
            }
        }
        
        return allBlocks
    }

    // MARK: - Private Helpers

    /// 從一組碎片建構一個 ParagraphBlock
    private static func buildParagraphBlock(from fragments: [TextFragment]) -> ParagraphBlock {
        // 計算外接矩形
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0

        for frag in fragments {
            minX = min(minX, frag.bounds.minX)
            minY = min(minY, frag.bounds.minY)
            maxX = max(maxX, frag.bounds.maxX)
            maxY = max(maxY, frag.bounds.maxY)
        }

        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // 斷字修復
        let lines = fragments.map { $0.text }
        var unified = recoverHyphenation(lines: lines)
        
        // 論文特化 OCR 錯誤修復
        unified = sanitizeScientificOCR(unified)

        return ParagraphBlock(
            fragments: fragments,
            role: .body,  // 預設為內文，稍後由 SemanticClassifier 重新分類
            unifiedText: unified,
            bounds: bounds
        )
    }

    /// 針對論文常見的 PDF 字體亂碼進行修正 (例如 þ 被解析成 +，\u{FFFD} 被解析成等號或乘號)
    private static func sanitizeScientificOCR(_ text: String) -> String {
        var clean = text
        
        // 修正加號
        clean = clean.replacingOccurrences(of: "þ", with: "+")
        
        // 將常見的評估指標後方的亂碼視為等號
        clean = Self.eqRegex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "$1 = ")
        
        // 將被夾在字母數字中間的亂碼視為乘號
        clean = Self.mulRegex.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "$1 * $2")
        
        // 清除剩餘無法辨識的亂碼
        clean = clean.replacingOccurrences(of: "\u{FFFD}", with: " ")
        
        return clean
    }
}
