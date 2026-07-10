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
    case yoloDocLayNet = "YOLO DocLayNet (v11s)"
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
                self.activeParser = YOLOLayoutParser(modelName: "yolov11s-doclaynet")
                self.currentParserName = "Auto: YOLO DocLayNet (Auto/Fallback)"
                AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO DocLayNet (Auto/Fallback)")
            }
        case .yoloStandard:
            self.activeParser = YOLOLayoutParser(modelName: "best")
            self.currentParserName = "Manual: YOLO Standard"
            AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO Standard (Manual)")
        case .yoloFast:
            self.activeParser = YOLOLayoutParser(modelName: "best_conf0.1")
            self.currentParserName = "Manual: YOLO Fast"
            AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO Fast (Manual)")
        case .yoloDocLayNet:
            self.activeParser = YOLOLayoutParser(modelName: "yolov11s-doclaynet")
            self.currentParserName = "Manual: YOLO DocLayNet (v11s)"
            AppLogger.shared.info("✅ 視覺引擎已切換為：YOLO DocLayNet (Manual)")
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
            } else if modelName == "best_conf0.1" {
                coreMLModel = try best_conf0_1(configuration: config).model
            } else {
                // 動態載入新模型
                let bundle = Bundle.main
                if let packageURL = bundle.url(forResource: modelName, withExtension:"mlmodelc") ?? bundle.url(forResource: modelName, withExtension:"mlpackage") {
                    let compiledURL = try MLModel.compileModel(at: packageURL)
                    coreMLModel = try MLModel(contentsOf: compiledURL, configuration: config)
                } else {
                    // Fallback
                    coreMLModel = try best_conf0_1(configuration: config).model
                }
            }
            #else
            // CLI 動態載入
            var actualModelName = modelName
            if modelName == "yolov11s-doclaynet" {
                actualModelName = "yolov10s_best"
            }
            let packageURL = Bundle.module.url(forResource: actualModelName, withExtension:"mlpackage")!
            let compiledURL = try MLModel.compileModel(at: packageURL)
            let coreMLModel = try MLModel(contentsOf: compiledURL, configuration: config)
            #endif
            
            let newModel = try VNCoreMLModel(for: coreMLModel)
            newModel.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
                "iouThreshold": 0.45,
                "confidenceThreshold": 0.25
            ])
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
                print("--- YOLO Request Finished ---")
                print("Error: \(String(describing: error))")
                print("Results count: \(request.results?.count ?? 0)")
                guard let results = request.results else {
                    continuation.resume(returning: [])
                    return
                }
                
                var blocks: [LayoutBlock] = []
                
                // Case 1: Model has built-in NMS (VNRecognizedObjectObservation)
                if let objectResults = results as? [VNRecognizedObjectObservation] {
                    for obs in objectResults {
                        let localRect = obs.boundingBox // 0~1, origin bottom-left
                        let globalBoundingBox = self.toGlobalBoundingBox(localRect: localRect, tileRect: tileRect, fullWidth: fullWidth, fullHeight: fullHeight)
                        
                        if let topLabel = obs.labels.first {
                            blocks.append(LayoutBlock(boundingBox: globalBoundingBox, label: topLabel.identifier, confidence: topLabel.confidence))
                        }
                    }
                }
                // Case 2: Raw tensor output (nms=False)
                else if let featureResults = results as? [VNCoreMLFeatureValueObservation] {
                    var yolo10MultiArray: MLMultiArray?
                    var confArray: MLMultiArray?
                    var coordArray: MLMultiArray?
                    
                    for feature in featureResults {
                        guard let multiArray = feature.featureValue.multiArrayValue else { continue }
                        if multiArray.shape.count == 3 && multiArray.shape[2].intValue == 6 {
                            // YOLOv10 NMS-Free format: [1, 300, 6]
                            yolo10MultiArray = multiArray
                        } else if multiArray.shape.count >= 2 {
                            if multiArray.shape.last?.intValue == 4 {
                                coordArray = multiArray
                            } else {
                                confArray = multiArray
                            }
                        }
                    }
                    
                    let classes = ["Caption", "Footnote", "Formula", "List-item", "Page-footer", "Page-header", "Picture", "Section-header", "Table", "Text", "Title"]
                    
                    if let yolo10 = yolo10MultiArray {
                        // YOLOv10 processing
                        let numBoxes = yolo10.shape[1].intValue
                        let pointer = UnsafeMutablePointer<Float32>(OpaquePointer(yolo10.dataPointer))
                        let strideBox = yolo10.strides[1].intValue
                        let confThreshold: Float32 = 0.25
                        
                        for b in 0..<numBoxes {
                            let conf = pointer[b * strideBox + 4]
                            if conf > confThreshold {
                                let x1 = pointer[b * strideBox + 0]
                                let y1 = pointer[b * strideBox + 1]
                                let x2 = pointer[b * strideBox + 2]
                                let y2 = pointer[b * strideBox + 3]
                                let classIdx = Int(pointer[b * strideBox + 5])
                                
                                // Coordinates are usually absolute to imgsz [0, 1024].
                                let nx = (x1 + x2) / 2.0 / 1024.0
                                let ny = (y1 + y2) / 2.0 / 1024.0
                                let nw = (x2 - x1) / 1024.0
                                let nh = (y2 - y1) / 1024.0
                                
                                let minX = CGFloat(nx - nw / 2)
                                let minY = CGFloat(1.0 - (ny + nh / 2))
                                let localRect = CGRect(x: minX, y: minY, width: CGFloat(nw), height: CGFloat(nh))
                                let globalBoundingBox = self.toGlobalBoundingBox(localRect: localRect, tileRect: tileRect, fullWidth: fullWidth, fullHeight: fullHeight)
                                
                                let label = classIdx < classes.count ? classes[classIdx] : "Unknown"
                                blocks.append(LayoutBlock(boundingBox: globalBoundingBox, label: label, confidence: conf))
                            }
                        }
                    }
                    else if let confArray = confArray, let coordArray = coordArray {
                        let numAnchors = confArray.shape[0].intValue
                        let numClasses = min(confArray.shape[1].intValue, 11)
                        
                        let confPointer = UnsafeMutablePointer<Float32>(OpaquePointer(confArray.dataPointer))
                        let coordPointer = UnsafeMutablePointer<Float32>(OpaquePointer(coordArray.dataPointer))
                        
                        let confStrideAnchor = confArray.strides[0].intValue
                        let confStrideClass = confArray.strides[1].intValue
                        
                        let coordStrideAnchor = coordArray.strides[0].intValue
                        let coordStrideDim = coordArray.strides[1].intValue
                        
                        let confThreshold: Float32 = 0.25
                        
                        for a in 0..<numAnchors {
                            var maxConf: Float32 = 0
                            var maxClassIdx: Int = 0
                            
                            for c in 0..<numClasses {
                                let conf = confPointer[a * confStrideAnchor + c * confStrideClass]
                                if conf > maxConf {
                                    maxConf = conf
                                    maxClassIdx = c
                                }
                            }
                            
                            if maxConf > confThreshold {
                                let cx = coordPointer[a * coordStrideAnchor + 0 * coordStrideDim]
                                let cy = coordPointer[a * coordStrideAnchor + 1 * coordStrideDim]
                                let w  = coordPointer[a * coordStrideAnchor + 2 * coordStrideDim]
                                let h  = coordPointer[a * coordStrideAnchor + 3 * coordStrideDim]
                                
                                let nx = cx > 2.0 ? cx / 1024.0 : cx
                                let ny = cy > 2.0 ? cy / 1024.0 : cy
                                let nw = w > 2.0 ? w / 1024.0 : w
                                let nh = h > 2.0 ? h / 1024.0 : h
                                
                                let minX = CGFloat(nx - nw / 2)
                                let minY = CGFloat(1.0 - (ny + nh / 2))
                                let localRect = CGRect(x: minX, y: minY, width: CGFloat(nw), height: CGFloat(nh))
                                let globalBoundingBox = self.toGlobalBoundingBox(localRect: localRect, tileRect: tileRect, fullWidth: fullWidth, fullHeight: fullHeight)
                                
                                let label = maxClassIdx < classes.count ? classes[maxClassIdx] : "Unknown"
                                blocks.append(LayoutBlock(boundingBox: globalBoundingBox, label: label, confidence: maxConf))
                            }
                        }
                        blocks = self.applyNMS(blocks: blocks, iouThreshold: 0.45)
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
    
    private func toGlobalBoundingBox(localRect: CGRect, tileRect: CGRect, fullWidth: CGFloat, fullHeight: CGFloat) -> CGRect {
        let localPixelWidth = localRect.width * tileRect.width
        let localPixelHeight = localRect.height * tileRect.height
        let localPixelX = localRect.minX * tileRect.width
        let localPixelY = localRect.minY * tileRect.height
        
        let tileBottomYFromTop = tileRect.maxY
        let tileBottomYFromBottom = fullHeight - tileBottomYFromTop
        
        let globalPixelX = tileRect.minX + localPixelX
        let globalPixelY = tileBottomYFromBottom + localPixelY
        
        let globalNormalizedX = globalPixelX / fullWidth
        let globalNormalizedY = globalPixelY / fullHeight
        let globalNormalizedWidth = localPixelWidth / fullWidth
        let globalNormalizedHeight = localPixelHeight / fullHeight
        
        return CGRect(x: globalNormalizedX, y: globalNormalizedY, width: globalNormalizedWidth, height: globalNormalizedHeight)
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
