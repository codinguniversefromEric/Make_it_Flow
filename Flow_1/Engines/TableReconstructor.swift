//
//  TableReconstructor.swift
//  Flow_1
//
//  Created by Libri-AI Engine on 2026/6/15.
//

import Foundation
import CoreGraphics

// MARK: - 表格結構解析器

/// 啟發式表格結構解析器 (Rule-based Table Structure Recognition)
enum TableReconstructor: Sendable {
    
    /// 嘗試將表格區域內的文字碎片重建為 Markdown 表格
    /// - Parameters:
    ///   - fragments: 落在表格視覺區域內的文字碎片
    ///   - tableBounds: 表格的邊界 (顯示座標系)
    /// - Returns: 若成功重建則回傳 Markdown 表格字串，否則回傳 nil (交由影像裁切處理)
    // MARK: - 核心解析方法
    
    nonisolated static func reconstruct(fragments: [TextFragment], tableBounds: CGRect) -> String? {
        guard fragments.count >= 4 else {
            // 碎片太少，可能是圖片表格或無法擷取文字，退回裁圖
            return nil
        }
        
        // 1. 垂直聚類：將碎片分組到不同的 Row 中
        // 先依照 midY 排序
        let sortedByY = fragments.sorted { $0.bounds.midY < $1.bounds.midY }
        
        var rows: [[TextFragment]] = []
        var currentRow: [TextFragment] = [sortedByY[0]]
        var currentYMax = sortedByY[0].bounds.maxY
        var currentYMin = sortedByY[0].bounds.minY
        
        for i in 1..<sortedByY.count {
            let frag = sortedByY[i]
            let midY = frag.bounds.midY
            
            // 判斷是否為同一行：midY 落在當前行的範圍內，或是 Y 差距很小
            let threshold = min(frag.bounds.height, currentYMax - currentYMin) * 0.5
            
            if midY <= currentYMax + threshold {
                currentRow.append(frag)
                currentYMax = max(currentYMax, frag.bounds.maxY)
                currentYMin = min(currentYMin, frag.bounds.minY)
            } else {
                rows.append(currentRow)
                currentRow = [frag]
                currentYMax = frag.bounds.maxY
                currentYMin = frag.bounds.minY
            }
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        // 確保至少有兩行才算是表格
        guard rows.count >= 2 else { return nil }
        
        // 2. 水平對齊：找出所有潛在的欄位 (Columns)
        // 收集所有碎片的 X 範圍並合併重疊區間
        var xRanges: [ClosedRange<CGFloat>] = fragments.map { $0.bounds.minX...$0.bounds.maxX }
        xRanges.sort { $0.lowerBound < $1.lowerBound }
        
        var mergedColumns: [ClosedRange<CGFloat>] = [xRanges[0]]
        for i in 1..<xRanges.count {
            let current = xRanges[i]
            let last = mergedColumns.last!
            
            // 如果有重疊，或者非常接近 (容許 15pt 的空隙)
            if current.lowerBound <= last.upperBound + 15.0 {
                let newRange = last.lowerBound...max(last.upperBound, current.upperBound)
                mergedColumns[mergedColumns.count - 1] = newRange
            } else {
                mergedColumns.append(current)
            }
        }
        
        // 確保至少有兩欄才算是表格
        guard mergedColumns.count >= 2 else { return nil }
        
        // 3. 填入資料格
        var tableData: [[String]] = []
        
        for rowFrags in rows {
            var rowCells: [String] = Array(repeating: "", count: mergedColumns.count)
            
            for frag in rowFrags {
                let midX = frag.bounds.midX
                // 找出最匹配的欄位
                if let colIndex = mergedColumns.firstIndex(where: { midX >= $0.lowerBound && midX <= $0.upperBound }) {
                    let text = frag.text.replacingOccurrences(of: "|", with: "\\|").trimmingCharacters(in: .whitespacesAndNewlines)
                    if rowCells[colIndex].isEmpty {
                        rowCells[colIndex] = text
                    } else {
                        // 同一格內有多個碎片，用空白連接
                        rowCells[colIndex] += " " + text
                    }
                } else {
                    // 尋找最近的欄位
                    var bestCol = 0
                    var minDistance = CGFloat.greatestFiniteMagnitude
                    for (index, colRange) in mergedColumns.enumerated() {
                        let distance = min(abs(midX - colRange.lowerBound), abs(midX - colRange.upperBound))
                        if distance < minDistance {
                            minDistance = distance
                            bestCol = index
                        }
                    }
                    let text = frag.text.replacingOccurrences(of: "|", with: "\\|").trimmingCharacters(in: .whitespacesAndNewlines)
                    if rowCells[bestCol].isEmpty {
                        rowCells[bestCol] = text
                    } else {
                        rowCells[bestCol] += " " + text
                    }
                }
            }
            
            tableData.append(rowCells)
        }
        
        // 4. 產生 Markdown 表格字串
        var markdown = ""
        
        // Header
        let header = tableData[0]
        markdown += "| " + header.joined(separator: " | ") + " |\n"
        
        // Separator
        let separator = Array(repeating: "---", count: mergedColumns.count)
        markdown += "| " + separator.joined(separator: " | ") + " |\n"
        
        // Data Rows
        for i in 1..<tableData.count {
            markdown += "| " + tableData[i].joined(separator: " | ") + " |\n"
        }
        
        return markdown + "\n"
    }
}
