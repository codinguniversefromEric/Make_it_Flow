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
enum VisionModelType: String, CaseIterable, Identifiable {
    case standard = "(小）(可刪除）預設版 (門檻 0.25)"
    case unsealed = "（小）(可刪除）解除封印版 (門檻 0.10)"
    case unsealed_1 = "（小）解除封印版 (門檻 0.10)+1024IMG"
    case unsealed_2 = "（大）解除封印版 (門檻 0.10)+1024IMG"
    
    var id: String { self.rawValue }
}

// MARK: - AI 視覺辨識引擎
class LayoutVisionManager: ObservableObject {
    static let shared = LayoutVisionManager()
    
    @Published var currentModelType: VisionModelType = .standard
    private var visionModel: VNCoreMLModel?
    private let modelQueue = DispatchQueue(label: "com.flow.visionmodel")
    
    private init() {
        switchModel(to: .standard)
    }
    
    func switchModel(to type: VisionModelType) {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            let coreMLModel: MLModel
            
            switch type {
            case .standard:
                coreMLModel = try best(configuration: config).model
            case .unsealed:
                coreMLModel = try best_conf0_1(configuration: config).model
            case .unsealed_1:
                coreMLModel = try best_imgsize1024(configuration: config).model
            case .unsealed_2:
                coreMLModel = try best_137MB(configuration: config).model
            }
            
            let newModel = try VNCoreMLModel(for: coreMLModel)
            modelQueue.sync {
                self.visionModel = newModel
            }
            
            DispatchQueue.main.async {
                self.currentModelType = type
                print("✅ 成功切換視覺模型至：\(type.rawValue)")
            }
        } catch {
            print("❌ 模型切換失敗: \(error)")
        }
    }
    
    func detectLayout(in cgImage: CGImage) async -> [VNRecognizedObjectObservation] {
        let currentModel = modelQueue.sync { self.visionModel }
        guard let model = currentModel else { return [] }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    continuation.resume(returning: results)
                } else {
                    continuation.resume(returning: [])
                }
            }
            request.imageCropAndScaleOption = .scaleFit
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("推論失敗: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
}
