import Foundation
import PDFKit

@MainActor
func main() async {
    let args = CommandLine.arguments
    guard args.count >= 3 else {
        print("Usage: Flow_CLI <input.pdf> <output.epub>")
        exit(1)
    }
    
    let inputPath = args[1]
    let outputPath = args[2]
    
    let inputURL = URL(fileURLWithPath: inputPath)
    guard let document = PDFDocument(url: inputURL) else {
        print("❌ Error: Could not load PDF at \(inputPath)")
        exit(1)
    }
    
    // Initialize required managers
    AppLogger.shared.info("Starting Flow_CLI processing for \(inputURL.lastPathComponent)")
    AppSettings.shared.selectedModel = .yoloStandard
    let processor = BatchProcessor()
    
    await processor.exportDocument(document, fileName: inputURL.deletingPathExtension().lastPathComponent)
    
    if let resultURL = processor.exportedFileURL {
        print("✅ Finished processing. Final file saved at \(resultURL.path)")
        do {
            if FileManager.default.fileExists(atPath: outputPath) {
                try FileManager.default.removeItem(atPath: outputPath)
            }
            try FileManager.default.copyItem(at: resultURL, to: URL(fileURLWithPath: outputPath))
            print("✅ File successfully copied to \(outputPath)")
        } catch {
            print("❌ Failed to copy to output path: \(error)")
            exit(1)
        }
    } else {
        print("❌ Processing failed or cancelled.")
        exit(1)
    }
}

// Run main
Task {
    await main()
    exit(0)
}
RunLoop.main.run()
