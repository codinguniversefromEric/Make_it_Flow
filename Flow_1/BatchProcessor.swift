//
//  BatchProcessor.swift
//  Flow_1
//
//  Created by 魏嘉賢 on 2026/6/13.
//  Rewritten for fully edge-compute content extraction on 2026/6/14.
//

import Foundation
import PDFKit
import Vision
import CoreML
import UIKit
import Combine
import CoreText
import ActivityKit

class BatchProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var exportedFileURL: URL?
    
    @Published var isCancelled: Bool = false
    private var currentActivity: Activity<FlowWidgetAttributes>? = nil

    func cancel() {
        self.isCancelled = true
    }

    @MainActor
    func exportDocument(_ document: PDFDocument, fileName: String? = nil) async {
        AppLogger.shared.info("Starting PDF export. Total pages: \(document.pageCount)")
        self.isCancelled = false
        self.isProcessing = true
        self.progress = 0.0
        self.exportedFileURL = nil

        // 📖 從 PDF 元資料萃取文件標題
        let initialTitle: String? = {
            let pdfMetadataTitle = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
            var title = pdfMetadataTitle
            if title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                title = fileName
            }
            return title
        }()
        
        let displayTitle = initialTitle ?? "Document"
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = FlowWidgetAttributes(documentName: displayTitle)
            let initialState = FlowWidgetAttributes.ContentState(progress: 0.0, statusMessage: "Starting...")
            do {
                if #available(iOS 16.2, *) {
                    self.currentActivity = try Activity.request(attributes: attributes, content: .init(state: initialState, staleDate: nil))
                } else {
                    self.currentActivity = try Activity.request(attributes: attributes, contentState: initialState)
                }
            } catch {
                AppLogger.shared.error("Activity request failed: \(error)")
            }
        }

        // 🚀 建立專屬的「匯出資料夾」與「圖片庫」
        let fm = FileManager.default
        let exportDir = fm.temporaryDirectory.appendingPathComponent("LibriAI_Export")
        
        // 如果之前有舊的，先清空
        if fm.fileExists(atPath: exportDir.path) {
            try? fm.removeItem(at: exportDir)
        }
        try? fm.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        let assetsDir = exportDir.appendingPathComponent("assets")
        try? fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        await Task.detached(priority: .userInitiated) {
            // 📖 These mutable variables are fully owned by the detached task to avoid data races
            var detectedTitle = initialTitle
            var fullMarkdown = ""
            var pendingContinuation: String? = nil
            let activity = await MainActor.run { self.currentActivity }
            for pageIndex in 0..<document.pageCount {
                if await MainActor.run(resultType: Bool.self, body: { self.isCancelled }) {
                    AppLogger.shared.info("Processing cancelled by user.")
                    await MainActor.run { self.isProcessing = false }
                    
                    if let activity = activity {
                        Task {
                            let finalState = FlowWidgetAttributes.ContentState(progress: 0.0, statusMessage: "Cancelled")
                            if #available(iOS 16.2, *) {
                                await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                            } else {
                                await activity.end(using: finalState, dismissalPolicy: .immediate)
                            }
                        }
                    }
                    
                    return
                }
                
                AppLogger.shared.info("Processing page \(pageIndex + 1)/\(document.pageCount)")
                // 🛑 讓 CPU 喘口氣
                await Task.yield()

                guard let page = document.page(at: pageIndex) else {
                    AppLogger.shared.warning("Failed to get page at index \(pageIndex)")
                    continue
                }

                let pageBounds = page.bounds(for: .cropBox)

                // 🎯 模型感知的渲染倍率：1024 input 模型用 3x，其他用 2x
                let currentModelType = LayoutVisionManager.shared.currentModelType
                let scale: CGFloat = (currentModelType == .unsealed_1 || currentModelType == .unsealed_2) ? 3.0 : 2.0
                let scaledSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
                
                // 🛡️ 記憶體防護罩
                var rawImage: UIImage? = nil
                var cgImg: CGImage? = nil

                autoreleasepool {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1.0
                    let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
                    let img = renderer.image { ctx in
                        let context = ctx.cgContext
                        UIColor.white.set()
                        context.fill(CGRect(origin: .zero, size: scaledSize))
                        context.saveGState()
                        context.translateBy(x: 0, y: scaledSize.height)
                        context.scaleBy(x: scale, y: -scale)
                        page.draw(with: .cropBox, to: context)
                        context.restoreGState()
                    }
                    rawImage = img
                    cgImg = img.cgImage
                }
                
                guard let validCGImg = cgImg, let validRawImage = rawImage else { continue }

                // ═══════════════════════════════════════════
                // STAGE 1: YOLO 視覺區域偵測 (圖片/表格/公式)
                // ═══════════════════════════════════════════

                let rawObservations = await LayoutVisionManager.shared.detectLayout(in: validCGImg)

                // NMS 過濾 (使用共用工具)
                var filteredObs: [VNRecognizedObjectObservation] = []
                let sortedObs = rawObservations.sorted { ($0.labels.first?.confidence ?? 0) > ($1.labels.first?.confidence ?? 0) }
                for obs in sortedObs {
                    var keep = true
                    let cRect = obs.boundingBox
                    for kObs in filteredObs {
                        let kRect = kObs.boundingBox
                        if NMSUtils.calcIoU(cRect, kRect) > 0.4 || NMSUtils.calcCoverage(cRect, kRect) > 0.8 {
                            keep = false; break
                        }
                    }
                    if keep { filteredObs.append(obs) }
                }

                // 分離視覺區域 vs 文字區域
                var visualRegions: [VisualRegion] = []
                var textRegionRects: [CGRect] = []
                var yoloHeaderRects: [CGRect] = []  // 🎯 保留 YOLO 的 Section-header 區域

                for obs in filteredObs {
                    let label = obs.labels.first?.identifier ?? "Unknown"
                    let conf = obs.labels.first?.confidence ?? 0
                    let cRect = VNImageRectForNormalizedRect(obs.boundingBox, Int(scaledSize.width), Int(scaledSize.height))
                    let dRect = CGRect(x: cRect.minX, y: scaledSize.height - cRect.maxY, width: cRect.width, height: cRect.height)

                    if label == "Picture" || label == "Figure" || label == "Formula" || label == "Table" {
                        visualRegions.append(VisualRegion(label: label, rect: dRect, confidence: conf))
                    } else {
                        textRegionRects.append(dRect)
                        // 🎯 記錄 YOLO 辨識出的標題區域
                        if label == "Section-header" || label == "Title" {
                            yoloHeaderRects.append(dRect)
                        }
                    }
                }

                print("📊 第 \(pageIndex + 1) 頁 YOLO: \(filteredObs.count) 區域 (\(visualRegions.count) 視覺, \(yoloHeaderRects.count) 標題)")

                // ═══════════════════════════════════════════
                // STAGE 2: PDFKit 富文字萃取 → TextFragment
                // ═══════════════════════════════════════════

                var textFragments: [TextFragment] = []

                if let selection = page.selection(for: pageBounds) {
                    for line in selection.selectionsByLine() {
                        guard let lineText = line.string, !lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                        let pRect = line.bounds(for: page)
                        let displayRect = CGRect(
                            x: pRect.minX * scale,
                            y: (pageBounds.height - pRect.maxY) * scale,
                            width: pRect.width * scale,
                            height: pRect.height * scale
                        )

                        // 🔍 排除落在視覺區域 (圖片/表格) 內的文字行
                        let lineMid = CGPoint(x: displayRect.midX, y: displayRect.midY)
                        let insideVisual = visualRegions.contains { region in
                            region.rect.contains(lineMid)
                        }
                        if insideVisual { continue }

                        // 📝 嘗試從 attributedString 擷取字體資訊
                        var fontSize: CGFloat = 12.0
                        var isBold = false

                        if let attrStr = line.attributedString {
                            attrStr.enumerateAttribute(.font, in: NSRange(location: 0, length: attrStr.length)) { value, _, _ in
                                if let font = value as? UIFont {
                                    fontSize = font.pointSize
                                    let traits = font.fontDescriptor.symbolicTraits
                                    isBold = traits.contains(.traitBold)
                                }
                            }
                        }

                        textFragments.append(TextFragment(
                            text: lineText,
                            bounds: displayRect,
                            fontSize: fontSize * scale,  // 轉換為顯示座標系的字體大小
                            isBold: isBold
                        ))
                    }
                }

                // ═══════════════════════════════════════════
                // STAGE 3: 佈局分析引擎 → 欄位偵測 + 段落重組
                // ═══════════════════════════════════════════

                print("📝 第 \(pageIndex + 1) 頁 PDFKit: \(textFragments.count) 文字行")

                var paragraphs = LayoutEngine.processPage(
                    fragments: textFragments,
                    pageWidth: scaledSize.width,
                    pageHeight: scaledSize.height
                )

                // ═══════════════════════════════════════════
                // STAGE 4: 語意分類 → 頁眉/頁腳/頁碼自動丟棄
                // ═══════════════════════════════════════════

                SemanticClassifier.classify(blocks: &paragraphs, pageHeight: scaledSize.height)

                // 🎯 YOLO 輔助標題偵測：如果段落與 YOLO Section-header 重疊，強制分類為 heading
                // 這是當 PDFKit 無法提供字型資訊時的救命稻草
                if !yoloHeaderRects.isEmpty {
                    for i in 0..<paragraphs.count {
                        if paragraphs[i].role == .body {
                            let paraMid = CGPoint(x: paragraphs[i].bounds.midX, y: paragraphs[i].bounds.midY)
                            let matchesYOLO = yoloHeaderRects.contains { headerRect in
                                headerRect.contains(paraMid) ||
                                NMSUtils.calcCoverage(paragraphs[i].bounds, headerRect) > 0.5
                            }
                            if matchesYOLO {
                                paragraphs[i].role = .heading
                            }
                        }
                    }
                }

                // 📊 日誌輸出
                let roleBreakdown = Dictionary(grouping: paragraphs, by: { $0.role })
                    .mapValues { $0.count }
                    .map { "\($0.key.rawValue):\($0.value)" }
                    .joined(separator: ", ")
                print("🏠 第 \(pageIndex + 1) 頁 分類: \(paragraphs.count) 段落 [​\(roleBreakdown)]")

                // ═══════════════════════════════════════════
                // STAGE 5: 組裝 Markdown
                // ═══════════════════════════════════════════

                var pageMD = ""
                var rawTextForLLM = ""

                // 📖 跨頁段落續接：如果上一頁有未完成的段落，接到這頁第一個 body 段落前面
                if let continuation = pendingContinuation {
                    if let firstBodyIdx = paragraphs.firstIndex(where: { $0.role == .body }) {
                        paragraphs[firstBodyIdx].unifiedText = continuation + " " + paragraphs[firstBodyIdx].unifiedText
                    }
                    pendingContinuation = nil
                }

                // 視覺區域 → 圖片裁切 (按 Y 位置排序)
                let sortedVisuals = visualRegions.sorted { $0.rect.minY < $1.rect.minY }
                for (index, region) in sortedVisuals.enumerated() {
                    let fileName = "page_\(pageIndex + 1)_item_\(index)"
                    if let _ = PDFImageExtractor.cropAndSaveImage(from: validRawImage, cropRect: region.rect, imageName: fileName, assetsURL: assetsDir) {
                        let prefix = region.label == "Table" ? "表格" : "圖表/圖片"
                        pageMD += "\n![\(prefix)：\(fileName)](assets/\(fileName).jpg)\n\n"
                    }
                }

                // 文字段落 → Markdown
                for block in paragraphs {
                    // 丟棄頁面假象
                    if SemanticClassifier.shouldDrop(block.role) { continue }

                    // 📖 擷取文件標題：如果 PDF 元資料沒有標題，使用第一個 .title 區塊
                    if block.role == .title {
                        let titleText = block.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if detectedTitle == nil {
                            // 首次偵測到標題 → 記錄為書名，不重複輸出到正文
                            detectedTitle = titleText
                            continue
                        } else if detectedTitle == titleText {
                            // 與已知書名相同 → 跳過 (防止 PDF metadata 與內文重複)
                            continue
                        }
                        // 不同的 .title → 降級為 heading 輸出
                    }

                    let md = SemanticClassifier.toMarkdown(block: block)
                    if !md.isEmpty {
                        rawTextForLLM += md
                    }
                }

                // 🧠 核心分流：決定文字處理路線
                if !rawTextForLLM.isEmpty {
                    if AppSettings.shared.useAI {
                        print("🧠 第 \(pageIndex + 1) 頁 → AI 修復中... (\(rawTextForLLM.count) 字元)")
                        let perfectMD = await LLMEngine.shared.refineMarkdown(rawText: rawTextForLLM)
                        print("✅ 第 \(pageIndex + 1) 頁 AI 修復完成 (\(perfectMD.count) 字元)")
                        pageMD += perfectMD + "\n\n"
                    } else {
                        pageMD += rawTextForLLM
                    }
                }

                // 📖 跨頁續接偵測：最後一個 body 段落是否未完結
                if let lastBody = paragraphs.last(where: { $0.role == .body }) {
                    let trimmed = lastBody.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let endsWithTerminator = trimmed.hasSuffix(".") || trimmed.hasSuffix("。") ||
                                             trimmed.hasSuffix("!") || trimmed.hasSuffix("！") ||
                                             trimmed.hasSuffix("?") || trimmed.hasSuffix("？") ||
                                             trimmed.hasSuffix(":") || trimmed.hasSuffix("：")
                    if !endsWithTerminator && trimmed.count > 20 {
                        pendingContinuation = trimmed
                        // 從 pageMD 中移除最後一個段落 (因為它會被接到下一頁)
                        // 簡易做法：保留，讓下一頁的開頭接上
                    }
                }

                // 📖 智慧分章
                if pageIndex > 0 {
                    if let firstBlock = paragraphs.first, firstBlock.role == .title || firstBlock.role == .heading {
                        if firstBlock.bounds.minY < 100 * scale {
                            fullMarkdown += "<CHAPTER_SPLIT>\n\n"
                        }
                    } else if pageIndex % 10 == 0 {
                        fullMarkdown += "<CHAPTER_SPLIT>\n\n"
                    }
                }

                fullMarkdown += pageMD + "---\n\n"

                // 🧹 即時釋放記憶體
                rawImage = nil
                cgImg = nil

                let currentProgress = Double(pageIndex + 1) / Double(document.pageCount)
                await MainActor.run { self.progress = currentProgress }
                
                if let activity = activity {
                    let currentState = FlowWidgetAttributes.ContentState(
                        progress: currentProgress,
                        statusMessage: "Processing page \(pageIndex + 1)"
                    )
                    Task {
                        if #available(iOS 16.2, *) {
                            await activity.update(ActivityContent(state: currentState, staleDate: nil))
                        } else {
                            await activity.update(using: currentState)
                        }
                    }
                }
            }

            // 🚀 完成所有頁面後，進行智慧路由打包
            // 📖 決定最終書名：PDF 元資料 → 第一個 .title 區塊 → 預設名稱
            let bookTitle = detectedTitle ?? "Libri-AI_轉譯報告"

            // 在 Markdown 最前面插入書名標題 (只有一份，不會重複)
            fullMarkdown = "# \(bookTitle)\n\n" + fullMarkdown

            // 安全檔名：移除不安全字元
            let safeFileName = bookTitle.replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .prefix(80)
            let mdURL = exportDir.appendingPathComponent("\(safeFileName).md")
            do {
                // 儲存 Markdown 備份
                try fullMarkdown.write(to: mdURL, atomically: true, encoding: .utf8)
                
                let finalEPUB: URL?
                
                // 🧠 智慧路由：根據頁數決定合成通道
                if document.pageCount > 50 {
                    AppLogger.shared.info("📚 偵測到長篇文件 (\(document.pageCount) 頁)，啟動書籍引擎...")
                    finalEPUB = EPUBSynthesizer.createBookEPUB(title: bookTitle, fullMarkdown: fullMarkdown, assetsURL: assetsDir)
                } else {
                    AppLogger.shared.info("📄 短篇論文模式 (\(document.pageCount) 頁)，啟動標準單頁引擎...")
                    finalEPUB = EPUBSynthesizer.createEPUB(title: bookTitle, markdown: fullMarkdown, assetsURL: assetsDir)
                }
                
                if let epubFile = finalEPUB {
                    AppLogger.shared.info("✅ 成功匯出 EPUB: \(epubFile.lastPathComponent)")
                    await MainActor.run {
                        self.exportedFileURL = epubFile
                        self.isProcessing = false
                    }
                    if let activity = activity {
                        Task {
                            let finalState = FlowWidgetAttributes.ContentState(progress: 1.0, statusMessage: "Done!")
                            if #available(iOS 16.2, *) {
                                await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                            } else {
                                await activity.end(using: finalState, dismissalPolicy: .immediate)
                            }
                        }
                    }
                } else {
                    AppLogger.shared.error("❌ EPUB 檔案未產生")
                    await MainActor.run { self.isProcessing = false }
                    if let activity = activity {
                        Task {
                            let currentProg = await MainActor.run { self.progress }
                            let finalState = FlowWidgetAttributes.ContentState(progress: currentProg, statusMessage: "Failed")
                            if #available(iOS 16.2, *) {
                                await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                            } else {
                                await activity.end(using: finalState, dismissalPolicy: .immediate)
                            }
                        }
                    }
                }
            } catch {
                AppLogger.shared.error("❌ 匯出失敗: \(error)")
                await MainActor.run { self.isProcessing = false }
                if let activity = activity {
                    Task {
                        let currentProg = await MainActor.run { self.progress }
                        let finalState = FlowWidgetAttributes.ContentState(progress: currentProg, statusMessage: "Failed")
                        if #available(iOS 16.2, *) {
                            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
                        } else {
                            await activity.end(using: finalState, dismissalPolicy: .immediate)
                        }
                    }
                }
            }
        }.value
    }
}

// MARK: - 圖片裁切工具

class PDFImageExtractor {
    
    /// 直接從已經渲染好的全頁圖片中裁切，100% 吻合 YOLO 視角！
    static func cropAndSaveImage(from sourceImage: UIImage, cropRect: CGRect, imageName: String, assetsURL: URL) -> String? {
        
        // 1. 取出底層的高畫質 CGImage
        guard let cgImage = sourceImage.cgImage else { return nil }
        
        // 2. ✂️ 直接拿 YOLO 算好的絕對座標來切 (毫秒級運算)
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        
        // 3. 轉回 UIImage 並準備存檔
        let finalImage = UIImage(cgImage: croppedCGImage)
        guard let imageData = finalImage.jpegData(compressionQuality: 0.85) else { return nil }
        
        let fileURL = assetsURL.appendingPathComponent("\(imageName).jpg")
        
        do {
            try imageData.write(to: fileURL)
            return "![圖表/圖片：\(imageName)](assets/\(imageName).jpg)"
        } catch {
            AppLogger.shared.error("❌ 圖片存檔失敗: \(error)")
            return nil
        }
    }
}
