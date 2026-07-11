//
//  LayoutEngine.swift
//  Flow_1
//
//  Created by Libri-AI Engine on 2026/6/14.
//

import Foundation
import CoreGraphics
import Vision

// MARK: - 佈局分析引擎：基於 YOLO 區塊的語意重組與幾何排序

/// 版面分析與重建引擎
enum LayoutEngine {

    // MARK: - Cached Regex Patterns
    private static let eqRegex = try! NSRegularExpression(pattern: "(?i)(Accuracy|Precision|Sensitivity|score|Recall|Specificity)\\s*\u{FFFD}\\s*")
    private static let mulRegex = try! NSRegularExpression(pattern: "([0-9A-Za-z])\\s*\u{FFFD}\\s*([0-9A-Za-z])")

    // MARK: - 1. 基於 LayoutBlock 的核心處理流程

    /// 使用 YOLO 給出的區塊，將 PDFKit 散落的文字碎片重新排序與封裝
    /// - Parameters:
    ///   - fragments: PDFKit 萃取的底層文字碎片
    ///   - blocks: YOLO 偵測出的佈局區塊 (LayoutBlock)
    ///   - pageWidth: 頁面寬度
    ///   - pageHeight: 頁面高度
    /// - Returns: 依人類閱讀順序排序好的完美段落

    static func processWithLayoutBlocks(
        fragments: [TextFragment],
        blocks: [LayoutBlock],
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> [ParagraphBlock] {
        guard !fragments.isEmpty else { return [] }
        guard !blocks.isEmpty else {
            // Fallback: 如果 YOLO 完全沒偵測到任何區塊，退回舊版純幾何演算法
            return processPage(fragments: fragments, pageWidth: pageWidth, pageHeight: pageHeight)
        }

        // 1. 幾何排序 YOLO 區塊 (Reading Order Algorithm)
        let sortedBlocks = sortLayoutBlocks(blocks, pageWidth: pageWidth, pageHeight: pageHeight)

        // 2. 將文字碎片分配到排序好的 YOLO 區塊中
        var blockFragmentsMap: [UUID: [TextFragment]] = [:]
        var unassignedFragments: [TextFragment] = []
        
        for frag in fragments {
            let fragArea = frag.bounds.width * frag.bounds.height
            let fragMid = CGPoint(x: frag.bounds.midX, y: frag.bounds.midY)
            
            if let matchedBlock = sortedBlocks.first(where: {
                let rect = VNImageRectForNormalizedRect($0.boundingBox, Int(pageWidth), Int(pageHeight))
                let invertedRect = CGRect(x: rect.minX, y: pageHeight - rect.maxY, width: rect.width, height: rect.height)
                
                let intersection = invertedRect.intersection(frag.bounds)
                if !intersection.isNull {
                    let intersectionArea = intersection.width * intersection.height
                    let expanded = invertedRect.insetBy(dx: -5, dy: -5)
                    return (fragArea > 0 && intersectionArea / fragArea > 0.4) || expanded.contains(fragMid)
                } else {
                    let expanded = invertedRect.insetBy(dx: -5, dy: -5)
                    return expanded.contains(fragMid)
                }
            }) {
                blockFragmentsMap[matchedBlock.id, default: []].append(frag)
            } else {
                unassignedFragments.append(frag)
            }
        }

        // 3. 依序組裝 YOLO 的 ParagraphBlock
        var finalParagraphs: [ParagraphBlock] = []
        for block in sortedBlocks {
            guard let frags = blockFragmentsMap[block.id], !frags.isEmpty else { continue }
            let sortedFrags = frags.sorted { $0.bounds.minY < $1.bounds.minY }
            let role = mapYoloLabelToRole(block.label)
            finalParagraphs.append(buildParagraphBlock(from: sortedFrags, role: role))
        }

        // 4. 將未被 YOLO 框選的邊角碎片，丟給舊版引擎進行備用排版
        if !unassignedFragments.isEmpty {
            let heuristicParagraphs = processPage(fragments: unassignedFragments, pageWidth: pageWidth, pageHeight: pageHeight)
            finalParagraphs.append(contentsOf: heuristicParagraphs)
        }
            
        // 將兩者混合後，使用標準的閱讀順序排序 (分區段 -> 分欄 -> 排序)
        return sortParagraphBlocks(finalParagraphs, pageWidth: pageWidth)
    }

    // MARK: - 段落排序

    /// 對最終的 ParagraphBlock 進行閱讀順序排序
    private static func sortParagraphBlocks(_ blocks: [ParagraphBlock], pageWidth: CGFloat) -> [ParagraphBlock] {
        guard blocks.count > 1 else { return blocks }
        
        let ySorted = blocks.sorted { $0.bounds.minY < $1.bounds.minY }
        print("🔍 ySorted blocks (\(ySorted.count)):")
        for b in ySorted {
            let text = b.unifiedText.replacingOccurrences(of: "\n", with: " ").prefix(30)
            print("  minY: \(String(format: "%.1f", b.bounds.minY)), text: \(text)")
        }
        
        var regions: [[ParagraphBlock]] = []
        var currentRegion: [ParagraphBlock] = [ySorted[0]]
        var currentMaxY = ySorted[0].bounds.maxY
        let regionBreakGap = pageWidth * 0.15
        
        for i in 1..<ySorted.count {
            let curr = ySorted[i]
            let gap = curr.bounds.minY - currentMaxY
            
            if gap > regionBreakGap {
                regions.append(currentRegion)
                currentRegion = [curr]
                currentMaxY = curr.bounds.maxY
            } else {
                currentRegion.append(curr)
                currentMaxY = max(currentMaxY, curr.bounds.maxY)
            }
        }
        if !currentRegion.isEmpty { regions.append(currentRegion) }
        
        var finalSorted: [ParagraphBlock] = []
        
        for region in regions {
            guard region.count > 1 else {
                finalSorted.append(contentsOf: region)
                continue
            }
            
            var columns: [[ParagraphBlock]] = []
            let xSorted = region.sorted { $0.bounds.minX < $1.bounds.minX }
            
            var currentColumn: [ParagraphBlock] = [xSorted[0]]
            var currentMaxX = xSorted[0].bounds.maxX
            let columnGutterGap = pageWidth * 0.025
            
            for i in 1..<xSorted.count {
            let curr = xSorted[i]
            let prev = xSorted[i-1]
            let xJump = curr.bounds.minX - prev.bounds.minX
            
            if xJump > pageWidth * 0.15 {
                    let minX = currentColumn.map { $0.bounds.minX }.min()!
                    let maxX = currentColumn.map { $0.bounds.maxX }.max()!
                    let colWidth = maxX - minX
                    
                    if colWidth < (pageWidth * 0.10) {
                        currentColumn.append(curr)
                    } else {
                        columns.append(currentColumn)
                        currentColumn = [curr]
                    }
                } else {
                    currentColumn.append(curr)
                }
            }
            if !currentColumn.isEmpty { columns.append(currentColumn) }
            
            for col in columns {
                let xySortedCol = col.sorted { a, b in
                    let yA = round(a.bounds.minY / 15.0)
                    let yB = round(b.bounds.minY / 15.0)
                    if yA == yB {
                        return a.bounds.minX < b.bounds.minX
                    }
                    return yA < yB
                }
                finalSorted.append(contentsOf: xySortedCol)
            }
        }
        
        print("🔍 finalSorted blocks (\(finalSorted.count)):")
        for b in finalSorted {
            let text = b.unifiedText.replacingOccurrences(of: "\n", with: " ").prefix(30)
            print("  minY: \(String(format: "%.1f", b.bounds.minY)), text: \(text)")
        }
        
        return finalSorted
    }
    // MARK: - 2. 閱讀順序演算法 (XY-Cut / Projection Profile)

    /// 根據人類閱讀邏輯 (先上後下，先左後右)，對 YOLO 區塊進行幾何排序
    private static func sortLayoutBlocks(_ blocks: [LayoutBlock], pageWidth: CGFloat, pageHeight: CGFloat) -> [LayoutBlock] {
        // 先換算成顯示座標的 CGRect
        let rectBlocks: [(block: LayoutBlock, rect: CGRect)] = blocks.map {
            let rect = VNImageRectForNormalizedRect($0.boundingBox, Int(pageWidth), Int(pageHeight))
            let inverted = CGRect(x: rect.minX, y: pageHeight - rect.maxY, width: rect.width, height: rect.height)
            return ($0, inverted)
        }
        
        // 按照 Y 座標由上而下初步排序
        let ySorted = rectBlocks.sorted { $0.rect.minY < $1.rect.minY }
        
        // 1. Y 軸大區塊切割 (Region Segmentation)
        var regions: [[(block: LayoutBlock, rect: CGRect)]] = []
        var currentRegion: [(block: LayoutBlock, rect: CGRect)] = [ySorted[0]]
        var currentMaxY = ySorted[0].rect.maxY
        let regionBreakGap = pageWidth * 0.15
        
        for i in 1..<ySorted.count {
            let curr = ySorted[i]
            let gap = curr.rect.minY - currentMaxY
            
            // 如果遇到明顯的 Y 軸斷層，視為新區塊 (例如摘要結束、雙欄開始)
            if gap > regionBreakGap {
                regions.append(currentRegion)
                currentRegion = [curr]
                currentMaxY = curr.rect.maxY
            } else {
                currentRegion.append(curr)
                currentMaxY = max(currentMaxY, curr.rect.maxY)
            }
        }
        if !currentRegion.isEmpty {
            regions.append(currentRegion)
        }
        
        // 2. 針對每個 Region 進行 X 軸分欄與排序
        var finalSortedBlocks: [LayoutBlock] = []
        
        for region in regions {
            let sortedRegionBlocks = sortRegionColumns(region, pageWidth: pageWidth)
            finalSortedBlocks.append(contentsOf: sortedRegionBlocks.map { $0.block })
        }
        
        return finalSortedBlocks
    }

    /// 在一個水平大區塊 (Region) 內，區分出左右欄位並進行排序
    private static func sortRegionColumns(_ region: [(block: LayoutBlock, rect: CGRect)], pageWidth: CGFloat) -> [(block: LayoutBlock, rect: CGRect)] {
        guard region.count > 1 else { return region }
        
        // 投射到 X 軸，找出欄位
        var columns: [[(block: LayoutBlock, rect: CGRect)]] = []
        
        // 將區塊依 X 座標由左至右排序
        let xSorted = region.sorted { $0.rect.minX < $1.rect.minX }
        
        var currentColumn: [(block: LayoutBlock, rect: CGRect)] = [xSorted[0]]
        var currentMaxX = xSorted[0].rect.maxX
        let columnGutterGap = pageWidth * 0.025
        
        for i in 1..<xSorted.count {
            let curr = xSorted[i]
            let prev = xSorted[i-1]
            let xJump = curr.rect.minX - prev.rect.minX
            
            if xJump > pageWidth * 0.15 {
                let minX = currentColumn.map { $0.rect.minX }.min()!
                let colWidth = currentMaxX - minX
                
                if colWidth < (pageWidth * 0.10) {
                    currentColumn.append(curr)
                } else {
                    columns.append(currentColumn)
                    currentColumn = [curr]
                }
            } else {
                currentColumn.append(curr)
            }
        }
        if !currentColumn.isEmpty {
            columns.append(currentColumn)
        }
        
        // 對每一欄內部的區塊進行 Y 軸排序 (由上而下)；若 Y 座標極為接近(同一行)，則依 X 軸排序(由左而右)
        var sortedRegion: [(block: LayoutBlock, rect: CGRect)] = []
        for col in columns {
            let xySortedCol = col.sorted { a, b in
                let yA = round(a.rect.minY / 15.0)
                let yB = round(b.rect.minY / 15.0)
                if yA == yB {
                    return a.rect.minX < b.rect.minX
                }
                return yA < yB
            }
            sortedRegion.append(contentsOf: xySortedCol)
        }
        
        return sortedRegion
    }


    // MARK: - Old Heuristic Engine Fallback

    /// 偵測頁面中的文字分欄與區域
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

    /// 將碎片根據文字特徵與幾何間距分組為段落
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

        let columnMinX = sorted.map { $0.bounds.minX }.min() ?? 0
        let columnMaxX = sorted.map { $0.bounds.maxX }.max() ?? 0
        let columnWidth = max(columnMaxX - columnMinX, 1.0)
        let columnMidX = columnMinX + columnWidth / 2.0

        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            let gap = curr.bounds.minY - prev.bounds.maxY

            let prevSize = prev.fontSize
            let currSize = curr.fontSize
            let isSameFont = abs(prevSize - currSize) < 1.0 && prev.isBold == curr.isBold
            
            // 計算水平重疊率
            let overlapMinX = max(prev.bounds.minX, curr.bounds.minX)
            let overlapMaxX = min(prev.bounds.maxX, curr.bounds.maxX)
            let overlap = max(0, overlapMaxX - overlapMinX)
            let minWidth = min(prev.bounds.width, curr.bounds.width)
            let overlapRatio = minWidth > 0 ? overlap / minWidth : 0
            
            // 短行判斷
            let prevIsShort = prev.bounds.width < columnWidth * 0.8
            let currIsShort = curr.bounds.width < columnWidth * 0.8
            
            // 置中判斷
            let prevIsCentered = prevIsShort && abs(prev.bounds.midX - columnMidX) < columnWidth * 0.15
            let currIsCentered = currIsShort && abs(curr.bounds.midX - columnMidX) < columnWidth * 0.15
            
            var shouldBreak = false

            // 特徵 1：短行結尾偵測 (上一行是短行且非置中，通常代表段落結束)
            let prevRightMargin = columnMaxX - prev.bounds.maxX
            if prevIsShort && !prevIsCentered && prevRightMargin > columnWidth * 0.15 {
                shouldBreak = true
            }
            
            // 特徵 2：置中短行偵測 (當前行或上一行是置中短行，通常是獨立標題)
            if prevIsCentered || currIsCentered {
                shouldBreak = true
            }

            // 特徵 3：間距超過 1.8 倍中位數
            if gap > paragraphBreakThreshold {
                shouldBreak = true
            }

            // 特徵 4：首行縮排 (X 座標向右縮進超過 1.5 倍字體大小)
            let xOffset = curr.bounds.minX - prev.bounds.minX
            if gap >= 0 && xOffset > (curr.fontSize * 1.5) {
                shouldBreak = true
            }

            // 特徵 5：字體大小變化超過 30%
            if prevSize > 0 && currSize > 0 {
                let sizeRatio = max(prevSize, currSize) / min(prevSize, currSize)
                if sizeRatio > 1.3 {
                    shouldBreak = true
                }
            }

            // 特徵 6：粗體狀態變化 + 輕微大小變化 (標題轉換)
            if prev.isBold != curr.isBold && prevSize > 0 && currSize > 0 {
                let sizeRatio = max(prevSize, currSize) / min(prevSize, currSize)
                if sizeRatio > 1.15 {
                    shouldBreak = true
                }
            }
            
            // 特徵 7：字型連續性與水平重疊率強制合併 (推翻弱斷行條件)
            if isSameFont && overlapRatio > 0.5 && gap < paragraphBreakThreshold * 1.5 {
                // 若非明顯首行縮排或置中標題，則強制合併
                if xOffset < (curr.fontSize * 3.0) && !prevIsCentered && !currIsCentered {
                    shouldBreak = false
                }
            }

            if shouldBreak {
                // 完成當前段落
                blocks.append(buildParagraphBlock(from: currentFrags, role: .body))
                currentFrags = [curr]
            } else {
                currentFrags.append(curr)
            }
        }

        // 收尾：最後一組
        if !currentFrags.isEmpty {
            blocks.append(buildParagraphBlock(from: currentFrags, role: .body))
        }

        return blocks
    }

    /// 純啟發式的版面解析與段落重組
    static func processPage(
        fragments: [TextFragment],
        pageWidth: CGFloat,
        pageHeight: CGFloat
    ) -> [ParagraphBlock] {
        guard !fragments.isEmpty else { return [] }
        
        // 1. 垂直區域分割 (Region Segmentation)
        // 將 fragments 按 Y 排序，找出大垂直間隙或版面改變處切分區域
        let sortedFrags = fragments.sorted { $0.bounds.minY < $1.bounds.minY }
        var regions: [[TextFragment]] = []
        var currentRegion: [TextFragment] = [sortedFrags[0]]
        var currentMaxY = sortedFrags[0].bounds.maxY
        
        for i in 1..<sortedFrags.count {
            let curr = sortedFrags[i]
            let gap = curr.bounds.minY - currentMaxY
            
            let isCurrFullWidth = curr.bounds.width > pageWidth * 0.6
            let isPrevFullWidth = sortedFrags[i-1].bounds.width > pageWidth * 0.6
            
            // 當遇到大間距 (>20pt)，或從全寬切換至多欄位時(gap>5pt容錯)，斷開區域
            if gap > 20.0 || (isCurrFullWidth != isPrevFullWidth && gap > 5.0) {
                regions.append(currentRegion)
                currentRegion = [curr]
                currentMaxY = curr.bounds.maxY
            } else {
                currentRegion.append(curr)
                currentMaxY = max(currentMaxY, curr.bounds.maxY)
            }
        }
        if !currentRegion.isEmpty {
            regions.append(currentRegion)
        }
        
        var allBlocks: [ParagraphBlock] = []
        
        // 2. 對每個區域獨立分欄並重組段落
        for regionFrags in regions {
            var regionBlocks: [ParagraphBlock] = []
            let columns = detectColumns(fragments: regionFrags, pageWidth: pageWidth, pageHeight: pageHeight)
            for column in columns {
                let paragraphs = groupIntoParagraphs(fragments: column.fragments, pageHeight: pageHeight)
                regionBlocks.append(contentsOf: paragraphs)
            }
            
            // 3. 對區域內的段落進行拓撲排序閱讀順序
            let sortedRegionBlocks = sortBlocksTopologically(regionBlocks)
            allBlocks.append(contentsOf: sortedRegionBlocks)
        }
        
        return allBlocks
    }

    /// 利用拓撲排序決定段落的閱讀順序
    static func sortBlocksTopologically(_ blocks: [ParagraphBlock]) -> [ParagraphBlock] {
        guard blocks.count > 1 else { return blocks }
        
        var adj = [Int: [Int]]()
        var inDegree = [Int: Int]()
        for i in 0..<blocks.count {
            adj[i] = []
            inDegree[i] = 0
        }
        
        for i in 0..<blocks.count {
            for j in 0..<blocks.count where i != j {
                let a = blocks[i].bounds
                let b = blocks[j].bounds
                
                var isA_Before_B = false
                
                // 條件 1: A 完全在 B 的上方且有水平重疊 (同欄上下關係)
                if a.maxY <= b.minY + 5.0 {
                    let overlapMinX = max(a.minX, b.minX)
                    let overlapMaxX = min(a.maxX, b.maxX)
                    if overlapMaxX > overlapMinX {
                        isA_Before_B = true
                    }
                }
                
                // 條件 2: A 在 B 的左方且有垂直重疊 (跨欄左右關係)
                if a.maxX <= b.minX + 5.0 {
                    let overlapMinY = max(a.minY, b.minY)
                    let overlapMaxY = min(a.maxY, b.maxY)
                    let minHeight = min(a.height, b.height)
                    if (overlapMaxY - overlapMinY) > minHeight * 0.3 {
                        isA_Before_B = true
                    }
                }
                
                if isA_Before_B {
                    adj[i]?.append(j)
                    inDegree[j, default: 0] += 1
                }
            }
        }
        
        var queue = [Int]()
        for i in 0..<blocks.count {
            if inDegree[i] == 0 { queue.append(i) }
        }
        
        var sortedIndices = [Int]()
        while !queue.isEmpty {
            // 佇列排序：無依賴的區塊中，優先選左上方的
            queue.sort { 
                let b1 = blocks[$0].bounds
                let b2 = blocks[$1].bounds
                if abs(b1.minX - b2.minX) > 20 { return b1.minX < b2.minX }
                return b1.minY < b2.minY
            }
            
            let curr = queue.removeFirst()
            sortedIndices.append(curr)
            
            for neighbor in adj[curr] ?? [] {
                inDegree[neighbor, default: 0] -= 1
                if inDegree[neighbor] == 0 { queue.append(neighbor) }
            }
        }
        
        // 若有環（例如極度不規則版面），退回單純的幾何排序
        if sortedIndices.count != blocks.count {
            return blocks.sorted { 
                if abs($0.bounds.minY - $1.bounds.minY) > 20 { return $0.bounds.minY < $1.bounds.minY }
                return $0.bounds.minX < $1.bounds.minX
            }
        }
        
        return sortedIndices.map { blocks[$0] }
    }

    // MARK: - 3. 語意轉換與段落封裝

    /// 將 YOLO 的標籤映射到我們定義的 SemanticRole
    private static func mapYoloLabelToRole(_ label: String) -> SemanticRole {
        switch label.lowercased() {
        case "title": return .title
        case "section-header": return .heading
        case "text": return .body
        case "list-item": return .listItem
        case "caption": return .caption
        case "footnote": return .footnote
        case "formula": return .formula
        case "picture": return .picture
        case "table": return .table
        case "page-header": return .pageHeader
        case "page-footer": return .pageFooter
        default: return .body
        }
    }

    /// 從一組連續的文字碎片建構一個 ParagraphBlock
    private static func buildParagraphBlock(from fragments: [TextFragment], role: SemanticRole) -> ParagraphBlock {
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
            role: role,
            unifiedText: unified,
            bounds: bounds
        )
    }

    /// 修復跨行斷字 (e.g., "hyperdon-" + "tia" → "hyperdontia")
    private static func recoverHyphenation(lines: [String]) -> String {
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

    /// 針對論文常見的 PDF 字體亂碼進行修正
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
