//
//  VisionEngine.swift
//  Flow_1
//
//  Created by 魏嘉賢 on 2026/6/13.
//

import Foundation
import CoreML
import Vision
import Combine

// MARK: - 可用的 AI 模型清單
public enum VisionModelType: String, CaseIterable, Identifiable {
    case auto = "Auto (RAM Based)"
    case yoloStandard = "YOLO Standard (best)"
    case yoloFast = "YOLO Fast (best_conf0.1)"
    case surya = "Surya Vision (FP16)"
    
    public var id: String { self.rawValue }
}

// MARK: - Layout Block 資料結構
public struct LayoutBlock: Identifiable {
    public let id = UUID()
    public let boundingBox: CGRect // 全域正規化座標 (0~1)，原點位於左下角 (遵循 Vision 標準)
    public let label: String
    public let confidence: Float
}

// MARK: - 抽象解析器介面
public protocol LayoutParser {
    func detectLayout(in cgImage: CGImage) async -> [LayoutBlock]
}

// MARK: - AI 視覺辨識引擎工廠 (Dynamic Dual-Engine)
public class LayoutVisionManager: ObservableObject {
    public static let shared = LayoutVisionManager()
    
    @Published public var currentParserName: String = "Unknown"
    private var activeParser: LayoutParser?
    
    private init() {
        setupEngine()
    }
    
    public func setupEngine() {
        let selectedModel = AppSettings.shared.selectedModel
        
        switch selectedModel {
        case .auto:
            let capability = MemoryManager.shared.currentCapability
            switch capability {
            case .highEnd:
                self.activeParser = SuryaLayoutParser()
                self.currentParserName = "Auto: Surya Engine (High-End)"
                AppLogger.shared.info("✅ 視覺引擎已切換為：Surya (Auto/High-Accuracy)")
            case .lowEnd:
                self.activeParser = YOLOLayoutParser(modelName: "best_conf0.1")
                self.currentParserName = "Auto: YOLO Engine (Low-End Fallback)"
                AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO Fast (Auto/Fallback)")
            }
        case .yoloStandard:
            self.activeParser = YOLOLayoutParser(modelName: "best")
            self.currentParserName = "Manual: YOLO Standard"
            AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO Standard (Manual)")
        case .yoloFast:
            self.activeParser = YOLOLayoutParser(modelName: "best_conf0.1")
            self.currentParserName = "Manual: YOLO Fast"
            AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO Fast (Manual)")
        case .surya:
            self.activeParser = SuryaLayoutParser()
            self.currentParserName = "Manual: Surya Engine"
            AppLogger.shared.info("✅ 視覺引擎已切換為：Surya (Manual)")
        }
    }
    
    public func detectLayout(in cgImage: CGImage) async -> [LayoutBlock] {
        guard let parser = activeParser else { return [] }
        return await parser.detectLayout(in: cgImage)
    }
}

// MARK: - YOLOLayoutParser (Fallback Engine)
class YOLOLayoutParser: LayoutParser {
    private var visionModel: VNCoreMLModel?
    private let modelQueue = DispatchQueue(label: "com.flow.visionmodel.yolo")
    
    init(modelName: String) {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            #if !CLI_MODE
            let coreMLModel: MLModel
            if modelName == "best" {
                coreMLModel = try best(configuration: config).model
            } else {
                coreMLModel = try best_conf0_1(configuration: config).model
            }
            #else
            // CLI 動態載入
            let packageURL = Bundle.module.url(forResource: modelName, withExtension:"mlpackage")!
            let compiledURL = try MLModel.compileModel(at: packageURL)
            let coreMLModel = try MLModel(contentsOf: compiledURL, configuration: config)
            #endif
            
            let newModel = try VNCoreMLModel(for: coreMLModel)
            modelQueue.sync {
                self.visionModel = newModel
            }
        } catch {
            AppLogger.shared.error("❌ YOLO 模型載入失敗: \(error)")
        }
    }
    
    func detectLayout(in cgImage: CGImage) async -> [LayoutBlock] {
        let currentModel = modelQueue.sync { self.visionModel }
        guard let model = currentModel else { return [] }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // 判斷是否需要切片
        let ratio = height / width
        var tiles: [(image: CGImage, rect: CGRect)] = []
        
        if ratio > 1.2 {
            // 長條形，進行垂直切片
            let numSlices = Int(ceil(ratio))
            let sliceHeight = height / CGFloat(numSlices)
            let overlap = sliceHeight * 0.1 // 10% overlap
            
            for i in 0..<numSlices {
                let startY = CGFloat(i) * sliceHeight - (i > 0 ? overlap : 0)
                var endY = CGFloat(i + 1) * sliceHeight + (i < numSlices - 1 ? overlap : 0)
                endY = min(endY, height)
                let actualStartY = max(0, startY)
                let actualHeight = endY - actualStartY
                
                let rect = CGRect(x: 0, y: actualStartY, width: width, height: actualHeight)
                if let cropped = cgImage.cropping(to: rect) {
                    tiles.append((cropped, rect))
                }
            }
        } else {
            // 比例接近方形，不需要切片
            tiles.append((cgImage, CGRect(x: 0, y: 0, width: width, height: height)))
        }
        
        // 使用 TaskGroup 並行處理所有切片
        var allBlocks: [LayoutBlock] = []
        
        await withTaskGroup(of: [LayoutBlock].self) { group in
            for tile in tiles {
                group.addTask {
                    return await self.processTile(tileImage: tile.image, tileRect: tile.rect, fullWidth: width, fullHeight: height, model: model)
                }
            }
            
            for await blocks in group {
                allBlocks.append(contentsOf: blocks)
            }
        }
        
        // 執行 NMS 過濾重複框
        return applyNMS(blocks: allBlocks, iouThreshold: 0.5)
    }
    
    private func processTile(tileImage: CGImage, tileRect: CGRect, fullWidth: CGFloat, fullHeight: CGFloat, model: VNCoreMLModel) async -> [LayoutBlock] {
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard let results = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var blocks: [LayoutBlock] = []
                for obs in results {
                    let localRect = obs.boundingBox // 0~1, origin bottom-left
                    
                    // 換算成 Tile 的絕對像素座標 (原點為 Tile 左下角)
                    let localPixelWidth = localRect.width * tileRect.width
                    let localPixelHeight = localRect.height * tileRect.height
                    let localPixelX = localRect.minX * tileRect.width
                    let localPixelY = localRect.minY * tileRect.height // 從 Tile 下方往上
                    
                    // 換算成整張影像的絕對像素座標 (原點為全圖左下角)
                    // Tile 底部距離全圖底部的距離 = 全圖高 - Tile底部Y坐標(從上面算)
                    let tileBottomYFromTop = tileRect.maxY
                    let tileBottomYFromBottom = fullHeight - tileBottomYFromTop
                    
                    let globalPixelX = tileRect.minX + localPixelX
                    let globalPixelY = tileBottomYFromBottom + localPixelY
                    
                    // 換算成全圖的正規化座標
                    let globalNormalizedX = globalPixelX / fullWidth
                    let globalNormalizedY = globalPixelY / fullHeight
                    let globalNormalizedWidth = localPixelWidth / fullWidth
                    let globalNormalizedHeight = localPixelHeight / fullHeight
                    
                    let globalBoundingBox = CGRect(x: globalNormalizedX, y: globalNormalizedY, width: globalNormalizedWidth, height: globalNormalizedHeight)
                    
                    if let topLabel = obs.labels.first {
                        let block = LayoutBlock(boundingBox: globalBoundingBox, label: topLabel.identifier, confidence: topLabel.confidence)
                        blocks.append(block)
                    }
                }
                continuation.resume(returning: blocks)
            }
            
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: tileImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                AppLogger.shared.error("YOLO 切片推論失敗: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    private func applyNMS(blocks: [LayoutBlock], iouThreshold: Float) -> [LayoutBlock] {
        let sortedBlocks = blocks.sorted { $0.confidence > $1.confidence }
        var keep: [LayoutBlock] = []
        
        for block in sortedBlocks {
            var shouldKeep = true
            for keptBlock in keep {
                if block.label == keptBlock.label {
                    let intersection = block.boundingBox.intersection(keptBlock.boundingBox)
                    if !intersection.isNull {
                        let intersectionArea = intersection.width * intersection.height
                        let area1 = block.boundingBox.width * block.boundingBox.height
                        let area2 = keptBlock.boundingBox.width * keptBlock.boundingBox.height
                        let unionArea = area1 + area2 - intersectionArea
                        let iou = intersectionArea / unionArea
                        
                        if iou > CGFloat(iouThreshold) {
                            shouldKeep = false
                            break
                        }
                    }
                }
            }
            if shouldKeep {
                keep.append(block)
            }
        }
        
        return keep
    }
}

// MARK: - SuryaLayoutParser (High-End Engine)
class SuryaLayoutParser: LayoutParser {
    private var visionModel: VNCoreMLModel?
    private let modelQueue = DispatchQueue(label: "com.flow.visionmodel.surya")
    
    init() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            guard let packageURL = Bundle.main.url(forResource: "surya_layout2_fp16", withExtension: "mlpackage") else {
                AppLogger.shared.error("❌ 找不到 surya_layout2_fp16.mlpackage")
                return
            }
            
            let compiledURL = try MLModel.compileModel(at: packageURL)
            let coreMLModel = try MLModel(contentsOf: compiledURL, configuration: config)
            let newModel = try VNCoreMLModel(for: coreMLModel)
            
            modelQueue.sync {
                self.visionModel = newModel
            }
            AppLogger.shared.info("✅ Surya 模型載入成功")
        } catch {
            AppLogger.shared.error("❌ Surya 模型載入失敗: \(error)")
        }
    }
    
    func detectLayout(in cgImage: CGImage) async -> [LayoutBlock] {
        let currentModel = modelQueue.sync { self.visionModel }
        guard let model = currentModel else { return [] }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let featureValue = results.first?.featureValue,
                      let multiArray = featureValue.multiArrayValue else {
                    continuation.resume(returning: [])
                    return
                }
                
                // TODO: 階段 2.5 - 將熱力圖轉換為 Bounding Box (待實作 OpenCV 等價邏輯)
                
                continuation.resume(returning: [])
            }
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                AppLogger.shared.error("Surya 推論失敗: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
}
