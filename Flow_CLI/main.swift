import Foundation
import PDFKit

@MainActor
func main() async {
    let args = CommandLine.arguments
    guard args.count >= 3 else {
        print("Usage: Flow_CLI <input.pdf> <output.md>")
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
    AppSettings.shared.selectedModel = .yoloDocLayNet
    let processor = BatchProcessor()
    
    await processor.exportDocument(document, fileName: inputURL.deletingPathExtension().lastPathComponent)
    
    // Wait for processing to finish if exportDocument is somehow not blocking
    // exportDocument is marked as async and we await it, so it blocks until done.
    
    if let resultURL = processor.exportedFileURL {
        print("✅ Finished processing. Final EPUB/MD saved at \(resultURL.path)")
        // Now let's copy the MD file to outputPath
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("LibriAI_Export")
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let safeFileName = fileName.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_").prefix(80)
        let mdURL = tmpDir.appendingPathComponent("\(safeFileName).md")
        
        if FileManager.default.fileExists(atPath: mdURL.path) {
            do {
                if FileManager.default.fileExists(atPath: outputPath) {
                    try FileManager.default.removeItem(atPath: outputPath)
                }
                try FileManager.default.copyItem(at: mdURL, to: URL(fileURLWithPath: outputPath))
                print("✅ Markdown copied to \(outputPath)")
            } catch {
                print("❌ Failed to copy markdown to output path: \(error)")
                exit(1)
            }
        } else {
            print("❌ Error: MD file not found at \(mdURL.path)")
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
