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
import Combine
import CoreText
#if os(iOS)
import UIKit
#endif

class BatchProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var exportedFileURL: URL?
    
    @Published var isCancelled: Bool = false
    private var currentTask: Task<Void, Never>?
    private let activityTracker = ActivityTracker()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
#if os(iOS)
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { _ in
                MemoryManager.shared.downgradeToLowEnd()
                LayoutVisionManager.shared.setupEngine()
            }
            .store(in: &cancellables)
#endif
    }
    
    func cancel() {
        self.isCancelled = true
        self.currentTask?.cancel()
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
        Task { await self.activityTracker.start(documentName: displayTitle) }
        
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
        
        self.currentTask = Task.detached(priority: .userInitiated) {
            // 📖 These mutable variables are fully owned by the detached task to avoid data races
            var detectedTitle = initialTitle
            var fullMarkdown = ""
            var pendingContinuation: String? = nil
            
            // 🌐 全域文件樣式分析
            AppLogger.shared.info("開始進行全域樣式分析...")
            let styleRegistry = StyleRegistry.analyze(document: document)
            AppLogger.shared.info("全域分析完成: Body \(styleRegistry.bodyFontSize)pt, H1 \(styleRegistry.h1FontSize)pt, H2 \(styleRegistry.h2FontSize)pt")
            
            for pageIndex in 0..<document.pageCount {
                if await MainActor.run(resultType: Bool.self, body: { self.isCancelled }) {
                    AppLogger.shared.info("Processing cancelled by user.")
                    await MainActor.run { self.isProcessing = false }
                    
                    await self.activityTracker.end(progress: 0.0, message: "Cancelled")
                    
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
                
                // 🎯 模型感知的渲染倍率：統一使用 2x
                let scale: CGFloat = 2.0
                let scaledSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
                
                // 🛡️ 記憶體防護罩
                var rawImage: AppImage? = nil
                var cgImg: CGImage? = nil
                
                autoreleasepool {
#if os(iOS)
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
#elseif os(macOS)
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    if let context = CGContext(data: nil, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                        context.fill(CGRect(origin: .zero, size: scaledSize))
                        context.saveGState()
                        context.translateBy(x: 0, y: scaledSize.height)
                        context.scaleBy(x: scale, y: -scale)
                        page.draw(with: .cropBox, to: context)
                        context.restoreGState()
                        
                        if let cgImage = context.makeImage() {
                            cgImg = cgImage
                            rawImage = NSImage(cgImage: cgImage, size: scaledSize)
                        }
                    }
#endif
                }
                
                guard let validCGImg = cgImg, let validRawImage = rawImage else { continue }
                
                // ═══════════════════════════════════════════
                // STAGE 1: YOLO 視覺區域偵測 (圖片/表格/公式)
                // ═══════════════════════════════════════════
                
                let rawObservations = await LayoutVisionManager.shared.detectLayout(in: validCGImg)
                
                // NMS 過濾 (使用共用工具)
                var filteredObs: [LayoutBlock] = []
                let sortedObs = rawObservations.sorted { $0.confidence > $1.confidence }
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
                
                for obs in filteredObs {
                    let label = obs.label
                    let conf = obs.confidence
                    let cRect = VNImageRectForNormalizedRect(obs.boundingBox, Int(scaledSize.width), Int(scaledSize.height))
                    let dRect = CGRect(x: cRect.minX, y: scaledSize.height - cRect.maxY, width: cRect.width, height: cRect.height)
                    
                    if label == "Picture" || label == "Figure" || label == "Formula" || label == "Table" {
                        visualRegions.append(VisualRegion(label: label, rect: dRect, confidence: conf))
                    } else {
                        textRegionRects.append(dRect)
                    }
                }
                
                print("📊 第 \(pageIndex + 1) 頁 YOLO: \(filteredObs.count) 區域 (\(visualRegions.count) 視覺)")
                
                // ═══════════════════════════════════════════
                // STAGE 2: PDFKit 富文字萃取 → TextFragment
                // ═══════════════════════════════════════════
                
                var textFragments: [TextFragment] = []
                var tableFragments: [Int: [TextFragment]] = [:]
                
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
                        
                        // 📝 嘗試從 attributedString 擷取字體資訊
                        var fontSize: CGFloat = 12.0
                        var isBold = false
                        
                        if let attrStr = line.attributedString {
                            attrStr.enumerateAttribute(.font, in: NSRange(location: 0, length: attrStr.length)) { value, _, _ in
                                if let font = value as? AppFont {
                                    fontSize = font.pointSize
                                    isBold = font.isAppFontBold
                                }
                            }
                        }
                        
                        let fragment = TextFragment(
                            text: lineText,
                            bounds: displayRect,
                            fontSize: fontSize * scale,
                            isBold: isBold
                        )
                        
                        // 🔍 排除落在視覺區域 (圖片/表格) 內的文字行，但保留表格內的碎片用於結構重建
                        let lineMid = CGPoint(x: displayRect.midX, y: displayRect.midY)
                        var handledByVisualRegion = false
                        for (index, region) in visualRegions.enumerated() {
                            if region.rect.contains(lineMid) {
                                if region.label == "Table" {
                                    tableFragments[index, default: []].append(fragment)
                                }
                                handledByVisualRegion = true
                                break
                            }
                        }
                        if handledByVisualRegion { continue }
                        
                        textFragments.append(fragment)
                    }
                }
                
                // ═══════════════════════════════════════════
                // STAGE 3: 佈局分析引擎 → 基於 YOLO 區塊的幾何重組
                // ═══════════════════════════════════════════
                
                print("📝 第 \(pageIndex + 1) 頁 PDFKit: \(textFragments.count) 文字行")
                
                var paragraphs = LayoutEngine.processWithLayoutBlocks(
                    fragments: textFragments,
                    blocks: filteredObs,
                    pageWidth: scaledSize.width,
                    pageHeight: scaledSize.height
                )
                
                // ═══════════════════════════════════════════
                // STAGE 4: 語意分類 → 頁眉/頁腳/頁碼自動丟棄
                // ═══════════════════════════════════════════
                
                SemanticClassifier.classify(blocks: &paragraphs, pageHeight: scaledSize.height, styleRegistry: styleRegistry)
                
                
                // 📊 日誌輸出
                let roleBreakdown = Dictionary(grouping: paragraphs, by: { $0.role })
                    .mapValues { $0.count }
                    .map { "\($0.key.rawValue):\($0.value)" }
                    .joined(separator: ", ")
                print("🏠 第 \(pageIndex + 1) 頁 分類: \(paragraphs.count) 段落 [​\(roleBreakdown)]")
                
                // ═══════════════════════════════════════════
                // STAGE 5: 跨頁續接與分段修剪
                // ═══════════════════════════════════════════
                
                // 1. 處理上一頁遺留的未完成段落
                if let continuation = pendingContinuation {
                    if let firstValidIdx = paragraphs.firstIndex(where: { !SemanticClassifier.shouldDrop($0.role) }) {
                        if paragraphs[firstValidIdx].role == .body {
                            let nextText = paragraphs[firstValidIdx].unifiedText
                            var mergedText = ""
                            
                            if continuation.hasSuffix("-") {
                                let cleanContinuation = String(continuation.dropLast())
                                if let firstChar = nextText.first, firstChar.isLowercase {
                                    mergedText = cleanContinuation + nextText
                                } else {
                                    mergedText = cleanContinuation + " " + nextText
                                }
                            } else {
                                mergedText = continuation + " " + nextText
                            }
                            paragraphs[firstValidIdx].unifiedText = mergedText
                            pendingContinuation = nil
                        } else {
                            // 第一個段落是標題等，將前一頁的結尾獨立為新段落
                            let contBlock = ParagraphBlock(fragments: [], role: .body, unifiedText: continuation, bounds: .zero)
                            paragraphs.insert(contBlock, at: firstValidIdx)
                            pendingContinuation = nil
                        }
                    } else {
                        // 這一頁沒有有效段落，暫且保留 continuation (或直接丟棄)
                    }
                }
                
                // 2. 擷取這一頁最後一個可能未完成的段落
                if let lastValidIdx = paragraphs.lastIndex(where: { !SemanticClassifier.shouldDrop($0.role) }),
                   paragraphs[lastValidIdx].role == .body {
                    let trimmed = paragraphs[lastValidIdx].unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let endsWithTerminator = trimmed.hasSuffix(".") || trimmed.hasSuffix("。") ||
                    trimmed.hasSuffix("!") || trimmed.hasSuffix("！") ||
                    trimmed.hasSuffix("?") || trimmed.hasSuffix("？") ||
                    trimmed.hasSuffix(":") || trimmed.hasSuffix("：")
                    // 防呆：如果是極短行，或是列表項，就不視為待續接
                    if !endsWithTerminator && trimmed.count > 20 {
                        pendingContinuation = trimmed
                        paragraphs.remove(at: lastValidIdx)
                    }
                }
                
                // ═══════════════════════════════════════════
                // STAGE 6: 組裝 Markdown 與智慧分章
                // ═══════════════════════════════════════════
                
                var pageMD = ""
                var rawTextForLLM = ""
                
                // 視覺區域 → 圖片裁切 (按 Y 位置排序)
                let sortedVisuals = zip(visualRegions.indices, visualRegions).sorted { $0.1.rect.minY < $1.1.rect.minY }
                for (indexInPage, (originalIndex, region)) in sortedVisuals.enumerated() {
                    let fileName = "page_\(pageIndex + 1)_item_\(indexInPage)"
                    
                    var tableReconstructed = false
                    if region.label == "Table", let frags = tableFragments[originalIndex] {
                        if let markdownTable = TableReconstructor.reconstruct(fragments: frags, tableBounds: region.rect) {
                            pageMD += "\n" + markdownTable + "\n\n"
                            tableReconstructed = true
                        }
                    }
                    
                    if !tableReconstructed {
                        if let _ = PDFImageExtractor.cropAndSaveImage(from: validRawImage, cropRect: region.rect, imageName: fileName, assetsURL: assetsDir) {
                            let prefix = region.label == "Table" ? "表格" : "圖表/圖片"
                            pageMD += "\n![\(prefix)：\(fileName)](assets/\(fileName).jpg)\n\n"
                        }
                    }
                }
                
                // 文字段落 → Markdown
                for block in paragraphs {
                    if SemanticClassifier.shouldDrop(block.role) { continue }
                    
                    // 📖 擷取文件標題
                    if block.role == .title {
                        let titleText = block.unifiedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if detectedTitle == nil {
                            detectedTitle = titleText
                            continue
                        } else if detectedTitle == titleText {
                            continue
                        }
                    }
                    
                    let md = SemanticClassifier.toMarkdown(block: block)
                    if !md.isEmpty {
                        rawTextForLLM += md
                    }
                }
                
                if !rawTextForLLM.isEmpty {
#if !CLI_MODE
                    if AppSettings.shared.useAI {
                        print("🧠 第 \(pageIndex + 1) 頁 → AI 修復中... (\(rawTextForLLM.count) 字元)")
                        let perfectMD = await LLMEngine.shared.refineMarkdown(rawText: rawTextForLLM)
                        print("✅ 第 \(pageIndex + 1) 頁 AI 修復完成 (\(perfectMD.count) 字元)")
                        pageMD += perfectMD + "\n\n"
                    } else {
                        pageMD += rawTextForLLM
                    }
#else
                    pageMD += rawTextForLLM
#endif
                }
                
                // 📖 智慧分章
                if pageIndex > 0 {
                    if let firstBlock = paragraphs.first(where: { !SemanticClassifier.shouldDrop($0.role) }),
                       firstBlock.role == .title || firstBlock.role == .heading {
                        
                        let text = firstBlock.unifiedText.lowercased()
                        let isChapterRegex = text.contains("chapter") || text.contains("第")
                        let isH1 = (firstBlock.fragments.first?.fontSize ?? 0) >= styleRegistry.h1FontSize * 0.95
                        
                        // 根據角色、正規表示式、或字體大小判定是否為章節起點
                        if firstBlock.role == .title || isChapterRegex || isH1 {
                            fullMarkdown += "<CHAPTER_SPLIT>\n\n"
                        } else if firstBlock.bounds.minY < 100 * scale {
                            // 備用：位於頁面最頂端的 heading 也可能是一個章節
                            fullMarkdown += "<CHAPTER_SPLIT>\n\n"
                        }
                    } else if pageIndex % 15 == 0 {
                        // 備用防呆
                        fullMarkdown += "<CHAPTER_SPLIT>\n\n"
                    }
                }
                
                fullMarkdown += pageMD + "---\n\n"
                
                // 🧹 即時釋放記憶體
                rawImage = nil
                cgImg = nil
                
                let currentProgress = Double(pageIndex + 1) / Double(document.pageCount)
                await MainActor.run { self.progress = currentProgress }
                
                await self.activityTracker.update(progress: currentProgress, message: "Processing page \(pageIndex + 1)")
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
#if !CLI_MODE
                // 🧠 智慧路由：根據頁數決定合成通道
                if document.pageCount > 50 {
                    AppLogger.shared.info("📚 偵測到長篇文件 (\(document.pageCount) 頁)，啟動書籍引擎...")
                    finalEPUB = EPUBSynthesizer.createBookEPUB(title: bookTitle, fullMarkdown: fullMarkdown, assetsURL: assetsDir)
                } else {
                    AppLogger.shared.info("📄 短篇論文模式 (\(document.pageCount) 頁)，啟動標準單頁引擎...")
                    finalEPUB = EPUBSynthesizer.createEPUB(title: bookTitle, markdown: fullMarkdown, assetsURL: assetsDir)
                }
#else
                finalEPUB = mdURL
#endif
                
                if let epubFile = finalEPUB {
                    AppLogger.shared.info("✅ 成功匯出 EPUB: \(epubFile.lastPathComponent)")
                    await MainActor.run {
                        self.exportedFileURL = epubFile
                        self.isProcessing = false
                    }
                    await self.activityTracker.end(progress: 1.0, message: "Done!")
                } else {
                    AppLogger.shared.error("❌ EPUB 檔案未產生")
                    await MainActor.run { self.isProcessing = false }
                    let currentProg = await MainActor.run { self.progress }
                    await self.activityTracker.end(progress: currentProg, message: "Failed")
                }
            } catch {
                AppLogger.shared.error("❌ 匯出匯出失敗: \(error)")
                await MainActor.run { self.isProcessing = false }
                let currentProg = await MainActor.run { self.progress }
                await self.activityTracker.end(progress: currentProg, message: "Failed")
            }
        }
        await self.currentTask?.value
    }
    
    
    // MARK: - 圖片裁切工具
    
    class PDFImageExtractor {
        
        /// 直接從已經渲染好的全頁圖片中裁切，100% 吻合 YOLO 視角！
        static func cropAndSaveImage(from sourceImage: AppImage, cropRect: CGRect, imageName: String, assetsURL: URL) -> String? {
            
            // 1. 取出底層的高畫質 CGImage
            guard let cgImage = sourceImage.cgImage else { return nil }
            
            // 2. ✂️ 直接拿 YOLO 算好的絕對座標來切 (毫秒級運算)
            guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
            
            // 3. 轉回 AppImage 並準備存檔
            let finalImage = AppImage(cgImage: croppedCGImage, size: cropRect.size)
            guard let imageData = finalImage.appJPEGData(compressionQuality: 0.85) else { return nil }
            
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
}
