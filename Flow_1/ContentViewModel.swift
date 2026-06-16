//
//  ContentViewModel.swift
//  Flow_1
//
//  ViewModel for the main content view, managing state and business logic.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    // MARK: - Dependencies
    let batchProcessor = BatchProcessor()
    let subscriptionManager = SubscriptionManager.shared
    let libraryStore = LibraryStore.shared
    let settings = AppSettings.shared
    
    // MARK: - UI State
    @Published var showPaywall = false
    @Published var showFilePicker = false
    @Published var isSettingsPresented = false
    @Published var dragOver = false
    @Published var showSuccessHUD = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    // MARK: - Document State
    @Published var pdfDocument: PDFDocument? = nil
    @Published var animState: AnimationState = .idle
    @Published var currentThumbnail: UIImage? = nil
    @Published var dynamicIslandCenter: CGPoint = .zero
    
    // MARK: - Combine: Forward nested ObservableObject changes
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // SwiftUI only observes @Published on this ViewModel.
        // Nested ObservableObjects must forward their changes manually.
        batchProcessor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        subscriptionManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        libraryStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
    
    // MARK: - Business Logic
    
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }) else { return false }
        
        provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { [weak self] url, error in
            guard let url = url else { return }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                DispatchQueue.main.async { self?.handlePickedPDF(url: tempURL) }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to import PDF: \(error.localizedDescription)"
                    self?.showErrorAlert = true
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
        return true
    }
    
    func handlePickedPDF(url: URL) {
        showFilePicker = false
        
        guard subscriptionManager.canConvert() else {
            showPaywall = true
            return
        }
        
        self.currentThumbnail = generatePDFThumbnail(from: url)
        withAnimation { animState = .showingThumbnail }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { animState = .suckingToIsland }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation { animState = .processing }
            
            if let doc = PDFDocument(url: url) {
                self.pdfDocument = doc
                let fileName = url.deletingPathExtension().lastPathComponent
                await batchProcessor.exportDocument(doc, fileName: fileName)
                
                if batchProcessor.exportedFileURL == nil {
                    withAnimation { animState = .idle }
                    if !batchProcessor.isCancelled {
                        errorMessage = "Conversion failed. Please try again."
                        showErrorAlert = true
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            } else {
                withAnimation { animState = .idle }
                errorMessage = "Unable to open PDF file. The file may be corrupted or password-protected."
                showErrorAlert = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    func finishConversion(epubURL: URL) {
        subscriptionManager.recordConversion()
        
        libraryStore.addItem(
            url: epubURL,
            title: epubURL.deletingPathExtension().lastPathComponent,
            thumbnail: self.currentThumbnail,
            diagnosticsSummary: ""
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            withAnimation(.easeInOut(duration: 0.5)) {
                animState = .idle
                currentThumbnail = nil
                
                if !settings.debugMode {
                    pdfDocument = nil
                    batchProcessor.exportedFileURL = nil
                    showSuccessHUD = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            
            if !settings.debugMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.showSuccessHUD = false
                    }
                }
            }
        }
    }
    
    func cancelProcessing() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        batchProcessor.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            animState = .idle
            currentThumbnail = nil
            pdfDocument = nil
            batchProcessor.exportedFileURL = nil
        }
    }
    
    func generatePDFThumbnail(from url: URL) -> UIImage? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let thumbnailWidth: CGFloat = 300
        let scale = thumbnailWidth / pageRect.width
        let thumbnailSize = CGSize(width: thumbnailWidth, height: pageRect.height * scale)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { ctx in
            UIColor.white.set(); ctx.fill(CGRect(origin: .zero, size: thumbnailSize))
            ctx.cgContext.translateBy(x: 0.0, y: thumbnailSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
