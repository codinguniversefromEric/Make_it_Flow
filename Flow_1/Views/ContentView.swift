import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import QuickLook

// MARK: - 動畫狀態

// 動畫狀態枚舉
enum AnimationState {
    case idle
    case showingThumbnail
    case suckingToIsland
    case processing
}

// MARK: - 主畫面整合
// 應用程式主畫面整合視圖
struct ContentView: View {
    @StateObject private var vm = ContentViewModel()
    @State private var isEditing = false
    @State private var selectedItems = Set<UUID>()
    @ObservedObject private var adManager = AdManager.shared
    
    var body: some View {
        ZStack(alignment: .top) {
            
            // 乾淨的背景
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 原生導航列與主內容
                NavigationView {
                    mainContentView
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                if isEditing {
                                    Button {
                                        if selectedItems.count == vm.libraryStore.items.count && !vm.libraryStore.items.isEmpty {
                                            selectedItems.removeAll()
                                        } else {
                                            selectedItems = Set(vm.libraryStore.items.map { $0.id })
                                        }
                                    } label: {
                                        Text(selectedItems.count == vm.libraryStore.items.count && !vm.libraryStore.items.isEmpty ? "Deselect All" : "Select All")
                                    }
                                } else {
                                    Button { vm.isSettingsPresented = true } label: { Label("Preferences", systemImage: "slider.horizontal.3") }
                                        .accessibilityLabel("Settings")
                                        .accessibilityHint("Open app preferences")
                                }
                            }
                            ToolbarItem(placement: .principal) {
                                Text("flow")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .tracking(-1.5)
                                    .foregroundColor(.primary)
                            }
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button {
                                    withAnimation {
                                        isEditing.toggle()
                                        if !isEditing {
                                            selectedItems.removeAll()
                                        }
                                    }
                                } label: {
                                    Text(isEditing ? "Done" : "Edit")
                                        .fontWeight(.medium)
                                }
                                if !isEditing {
                                    Button(action: { vm.showFilePicker = true }) {
                                        Image(systemName: "plus")
                                            .font(.headline)
                                    }
                                    .accessibilityLabel("Add PDF")
                                    .accessibilityHint("Open file picker to select a PDF for conversion")
                                }
                            }
                        }
                        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
                }
                .navigationViewStyle(.stack)
                
                // 廣告 Banner (若未付費)
                if !vm.subscriptionManager.isPremium {
                    AdBannerView()
                        .frame(height: 50)
                        .background(Color(UIColor.systemGroupedBackground))
                }
            }
            
            // 隱藏的定位器
            Color.clear
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.clear)
                        .frame(width: 10, height: 1)
                        .background(AnchorDetector(coordinateSpace: .global))
                        .offset(y: -32)
                }
                .allowsHitTesting(false)
            
            // 流暢的水波紋動畫層
            animationOverlay
            
            // 全螢幕打勾動畫 HUD (FaceID Style)
            if vm.showSuccessHUD {
                FaceIDCheckmarkView()
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 30, y: 15)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .zIndex(100)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Conversion complete")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .onPreferenceChange(IslandAnchorKey.self) { center in
            if center != .zero && vm.dynamicIslandCenter != center {
                vm.dynamicIslandCenter = center
            }
        }
        .sheet(isPresented: $vm.showFilePicker) {
            PDFDocumentPicker { url in
                vm.handlePickedPDF(url: url)
            }
        }
        .sheet(isPresented: $vm.isSettingsPresented) {
            SettingsView()
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
                .environmentObject(vm.subscriptionManager)
        }
        .onChange(of: vm.batchProcessor.exportedFileURL) { newURL in
            if let epubURL = newURL {
                vm.finishConversion(epubURL: epubURL)
            }
        }
        .alert("Conversion Error", isPresented: $vm.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage)
        }
        .fullScreenCover(isPresented: $vm.showInterstitialAd) {
            InterstitialAdView {
                vm.showInterstitialAd = false
                vm.onInterstitialAdDismissed()
            }
        }
    }
}

// MARK: - UI 元件擴充
extension ContentView {
    
    @ViewBuilder
    private var mainContentView: some View {
        if let document = vm.pdfDocument {
            if vm.settings.debugMode {
                documentDebugView(document)
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("Processing document...")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.secondary)
                    if vm.batchProcessor.isProcessing {
                        ProgressView(value: vm.batchProcessor.progress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 200)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            homeLibraryView
        }
    }
    
    // 🌟 YOLO Debug 視圖 (包含返回按鈕)
    private func documentDebugView(_ document: PDFDocument) -> some View {
        VStack(spacing: 0) {
            // 頂部控制列
            HStack {
                Button {
                    vm.pdfDocument = nil
                    vm.batchProcessor.cancel()
                } label: {
                    Label("Close Debug", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .accessibilityLabel("Close debug view")
                .accessibilityHint("Return to the library")
                Spacer()
                Text("YOLO Debug Mode")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        DebugPageView(document: document, pageIndex: index)
                    }
                }
            }
            .id("\(document.documentURL?.absoluteString ?? UUID().uuidString)-\(vm.settings.debugMode)")
        }
    }
    
    // 🌟 統一的首頁書庫 (Home Library)
    // 首頁書庫視圖
    private var homeLibraryView: some View {
        ZStack {
            ScrollView {
                if vm.libraryStore.items.isEmpty {
                    emptyLibraryView
                } else {
                    populatedLibraryView
                }
            }
            
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    VStack(spacing: 0) {
                        Divider()
                        Button(role: .destructive) {
                            withAnimation {
                                let itemsToDelete = vm.libraryStore.items.filter { selectedItems.contains($0.id) }
                                for item in itemsToDelete {
                                    vm.libraryStore.deleteItem(item)
                                }
                                selectedItems.removeAll()
                                isEditing = false
                            }
                        } label: {
                            Text("Delete Selected (\(selectedItems.count))")
                                .font(.headline)
                                .foregroundColor(selectedItems.isEmpty ? .gray : .red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .disabled(selectedItems.isEmpty)
                        .background(.ultraThinMaterial)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // 全域拖曳高亮遮罩
            if vm.dragOver {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 3, dash: [12, 8]))
                    )
                    .padding(16)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.2), value: vm.dragOver)
                    .accessibilityLabel("Drop zone active. Release to import PDF")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: [.pdf], isTargeted: $vm.dragOver) { providers in vm.handleDrop(providers) }
        .onAppear {
            adManager.preloadAdsIfNeeded()
        }
    }
    
    @ViewBuilder
    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 72))
                .foregroundColor(Color.secondary.opacity(0.3))
            Text("Library is empty")
                .font(.title2.weight(.bold))
            Text("Drag & drop PDFs here\nor tap '+' to add")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 160)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Library is empty. Drag a PDF here or tap the add button to get started.")
        
        if !vm.subscriptionManager.isPremium {
            nativeAdSection
                .padding(.top, 40)
        }
    }
    
    @ViewBuilder
    private var populatedLibraryView: some View {
        if !vm.subscriptionManager.isPremium {
            nativeAdSection
        }
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(vm.libraryStore.items) { file in
                            VStack {
                                if let thumb = vm.libraryStore.loadThumbnail(for: file) {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 180)
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(UIColor.secondarySystemFill))
                                        .frame(height: 180)
                                }
                                Text(file.title)
                                    .font(.caption).fontWeight(.medium).foregroundColor(.primary)
                                    .lineLimit(1).padding(.top, 8)
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                            .overlay(
                                Group {
                                    if !isEditing {
                                        if #available(iOS 16.0, *) {
                                            ShareLink(item: file.url) {
                                                Color.clear
                                            }
                                        } else {
                                            Color.clear
                                        }
                                    }
                                }
                            )
                            .overlay(alignment: .bottomTrailing) {
                                if isEditing {
                                    Image(systemName: selectedItems.contains(file.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedItems.contains(file.id) ? .blue : .gray.opacity(0.5))
                                        .background(Circle().fill(Color.white))
                                        .offset(x: -12, y: -12)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .onTapGesture {
                                if isEditing {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        if selectedItems.contains(file.id) {
                                            selectedItems.remove(file.id)
                                        } else {
                                            selectedItems.insert(file.id)
                                        }
                                    }
                                }
                            }
                            .contextMenu {
                                if #available(iOS 16.0, *) {
                                ShareLink(item: file.url) {
                                    Label("Share EPUB", systemImage: "square.and.arrow.up")
                                }
                            }
                                Button(role: .destructive) {
                                    vm.libraryStore.deleteItem(file)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(file.title)
                            .accessibilityHint("Long press to share this EPUB")
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 80)
    }
    
    // 🌟 原生浮動按鈕 (已移除，改由右上角 ToolbarItem 處理)
    // MARK: 動畫層
    @ViewBuilder
    private var nativeAdSection: some View {
        Group {
            if let ad = adManager.nativeAd {
                AdMobNativeView(nativeAd: ad)
            } else {
                ProgressView()
            }
        }
    }
    @ViewBuilder
    private var animationOverlay: some View {
        if vm.animState != .idle {
            GeometryReader { geo in
                let islandY = vm.dynamicIslandCenter.y == .zero ? 32 : vm.dynamicIslandCenter.y
                
                ZStack(alignment: .top) {
                    
                    if vm.animState == .showingThumbnail || vm.animState == .suckingToIsland {
                        Color.black.opacity(vm.animState == .showingThumbnail ? 0.15 : 0.0)
                            .ignoresSafeArea()
                            .animation(.easeInOut(duration: 0.3), value: vm.animState)
                            
                        if let thumb = vm.currentThumbnail {
                            Image(uiImage: thumb)
                                .resizable().scaledToFit().frame(width: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                                .position(
                                    x: geo.size.width / 2,
                                    y: vm.animState == .showingThumbnail ? (geo.size.height / 2) : islandY - 100
                                )
                                .scaleEffect(vm.animState == .showingThumbnail ? 1.0 : 0.02)
                                .opacity(vm.animState == .suckingToIsland ? 0.0 : 1.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: vm.animState)
                        }
                    }
                    
                    if vm.animState == .processing {
                        ZStack {
                            GlassLiquidView(progress: vm.batchProcessor.progress, islandY: islandY)
                                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                            
                            // 原生取消按鈕加上進度文字 (Visibility of System Status)
                            VStack(spacing: 12) {
                                Spacer()
                                
                                let percent = Int(round(vm.batchProcessor.progress * 100))
                                Text(percent >= 100 ? "EPUB is ready" : "\(percent)%")
                                    .font(.system(size: percent >= 100 ? 18 : 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                                    .accessibilityLabel(percent >= 100 ? "Finalizing conversion" : "Converting, \(percent) percent complete")
                                    .accessibilityAddTraits(.updatesFrequently)
                                
                                Button(role: .destructive, action: {
                                    vm.cancelProcessing()
                                }) {
                                    Label("Cancel", systemImage: "xmark.circle.fill")
                                        .font(.headline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .accessibilityLabel("Cancel conversion")
                                .accessibilityHint("Stop the current PDF to EPUB conversion")
                                .controlSize(.large)
                                .shadow(color: .red.opacity(0.2), radius: 5, y: 2)
                            }
                            .padding(.bottom, 60)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    }

// MARK: - 流暢的 Shape 水滴進度條 (無 Canvas 負擔)
// 流暢水波紋進度條視圖
struct GlassLiquidView: View {
    var progress: Double // 0.0 ~ 1.0
    var islandY: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                // 絲滑的波動頻率
                let phase = now * .pi * 2 / 2.0
                
                // 加上 40 確保水波在 100% 時能徹底沉到畫面最底部（不會殘留波浪邊緣）
                let targetMaxY = geo.size.height + 40
                let currentY = islandY + (targetMaxY - islandY) * CGFloat(animatedProgress)
                
                ZStack {
                    WaveShape(yOffset: currentY, phase: phase + .pi/2, amplitude: 12)
                        .fill(Color.accentColor.opacity(0.15))
                    
                    WaveShape(yOffset: currentY, phase: phase, amplitude: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            WaveShape(yOffset: currentY, phase: phase, amplitude: 18)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                }
            }
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newVal in
            // 彈簧動畫讓進度跟隨時有絲滑的物理拉扯感
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animatedProgress = newVal
            }
        }
    }
}

struct WaveShape: Shape {
    var yOffset: CGFloat
    var phase: Double
    var amplitude: CGFloat
    
    // 只有 yOffset 需要 SwiftUI 內建插值，phase 由 TimelineView 強制達到 120Hz 刷新
    var animatableData: CGFloat {
        get { yOffset }
        set { yOffset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: yOffset))
        
        let frequency = 1.0
        // 降低步進值，讓曲線更加細膩絲滑
        for x in stride(from: 0.0, through: Double(width), by: 2.0) {
            let relativeX = x / Double(width)
            let sine = sin(relativeX * .pi * 2 * frequency + phase)
            let y = yOffset + amplitude * CGFloat(sine)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}


// MARK: - UIDocumentPickerViewController Wrapper
// PDF 檔案選擇器
struct PDFDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Copy to temp directory so the file remains accessible after releasing the security scope
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                onPick(tempURL)
            } catch {
                // Fallback to original URL if copy fails
                onPick(url)
            }
        }
    }
}

// MARK: - 座標偵測工具
// 動態島座標紀錄鍵
struct IslandAnchorKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct AnchorDetector: View {
    let coordinateSpace: CoordinateSpace
    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: coordinateSpace)
            let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
            Color.clear
                .preference(key: IslandAnchorKey.self, value: centerPoint)
        }
    }
}

// MARK: - 簡易閱讀器
// 簡易 EPUB 閱讀器
struct EPUBReaderView: View {
    let file: LibraryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if file.url.pathExtension.lowercased() == "epub" {
                QuickLookPreview(url: file.url)
            } else {
                QuickLookPreview(url: file.url)
            }
        }
        .navigationTitle(file.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as NSURL
        }
    }
}

// MARK: - FaceID 風格打勾動畫
// FaceID 風格的打勾動畫視圖
struct FaceIDCheckmarkView: View {
    @State private var drawCircle: CGFloat = 0.0
    @State private var drawCheck: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // 底層圓軌道
                Circle()
                    .stroke(Color.gray.opacity(0.15), style: StrokeStyle(lineWidth: 6))
                
                // 動畫圓軌道
                Circle()
                    .trim(from: 0, to: drawCircle)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                // 動畫打勾
                Path { path in
                    path.move(to: CGPoint(x: 28, y: 50))
                    path.addLine(to: CGPoint(x: 42, y: 64))
                    path.addLine(to: CGPoint(x: 72, y: 34))
                }
                .trim(from: 0, to: drawCheck)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 100, height: 100)
            
            Text("Done")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .opacity(drawCheck == 1.0 ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: drawCheck)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
                drawCircle = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.35)) {
                drawCheck = 1.0
            }
        }
    }
}

