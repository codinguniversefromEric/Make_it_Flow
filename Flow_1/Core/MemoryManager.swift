import Foundation
#if canImport(os)
import os
#endif

public enum DeviceCapability {
    case highEnd // 6GB RAM or more
    case lowEnd  // 4GB RAM or less
}

public class MemoryManager {
    public static let shared = MemoryManager()
    
    // Dynamic capability that can be downgraded if memory warnings occur
    public var currentCapability: DeviceCapability
    
    private init() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInGB = physicalMemory / (1024 * 1024 * 1024)
        
        AppLogger.shared.info("📱 Device Physical Memory: \(memoryInGB) GB")
        
        // 6GB RAM is the threshold for Surya (High-End)
        if memoryInGB >= 6 {
            self.currentCapability = .highEnd
            AppLogger.shared.info("🚀 Device classified as High-End (Surya Engine enabled)")
        } else {
            self.currentCapability = .lowEnd
            AppLogger.shared.info("🔋 Device classified as Low-End (YOLO Engine fallback enabled)")
        }
    }
    
    public func downgradeToLowEnd() {
        if currentCapability == .highEnd {
            currentCapability = .lowEnd
            AppLogger.shared.warning("⚠️ Memory Warning received! Downgrading to Low-End YOLO Engine.")
        }
    }
    
    public func checkAvailableMemory() -> Int64 {
#if os(iOS)
        if #available(iOS 13.0, *) {
            return Int64(os_proc_available_memory())
        }
#endif
        return -1
    }
}
