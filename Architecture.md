# Make_it_Flow 系統架構與技術報告

本文件總結了 `Make_it_Flow` (PDF 轉 EPUB 引擎) 的核心架構設計，特別紀錄了專案在演進過程中實作的各項防禦性工程與最佳實踐，以供未來維護與 KMP 重構參考。

## 1. 核心管線 (The Core Pipeline)

目前的系統管線設計為單向資料流，專為高效處理圖文並茂的學術論文與書籍而生：

1. **VisionEngine (視覺推論)**：透過 CoreML 載入 YOLO 模型。負責辨識頁面上的 14 類版面區塊 (Title, Text, Table, Figure 等)。
2. **PDFKit Extraction (文字擷取)**：透過原生 PDFKit API 抓取文字層 (Text Layer)，並取得文字的絕對座標與字體大小。
3. **LayoutEngine (幾何重組)**：(即將移轉至 KMP) 將上述兩者結合，透過「中心點包含」或「IoU 交集」演算法，將散落的文字碎片指派進 YOLO 的排版框內，並執行拓樸排序 (Topological Sorting)。
4. **EPUBSynthesizer (合規封裝)**：將整理好的標籤轉換為標準的 Markdown/XHTML，並遵守嚴格的 ZIP 規範打包為 EPUB。

## 2. 記憶體防護與 OOM 預防 (Memory Safety)

PDF 處理是極度消耗 RAM 的操作。iOS 設備的記憶體有限，處理數百頁的 PDF 時極易發生 Out of Memory (OOM) 崩潰。本專案實作了以下防護機制，未來的開發者必須知悉並維持這些設計：

* **逐頁處理與 AutoReleasePool**
  在 `BatchProcessor.swift` 的迴圈中，嚴格使用了 `autoreleasepool` 來包裝每一頁的渲染與處理邏輯。這確保了前一頁生成的龐大 `CGImage` 與 `MLMultiArray` 張量能夠在換頁前被徹底釋放。
  
* **CPU 讓權 (`Task.yield`)**
  每處理完一頁，主動呼叫 `await Task.yield()`，防止繁重的迴圈獨佔 Main Thread 或導致系統 Watchdog 強制終止 App。
  
* **克制的渲染解析度 (2x Scale)**
  在將 PDF 頁面轉換為圖片餵給模型時，統一採用 `scale = 2.0`。這能在「保留足夠解析度供 YOLO 辨識」與「防止記憶體爆炸」之間取得完美平衡。嚴禁為了追求清晰度盲目將 scale 提升至 3.0 或 4.0。

## 3. KMP 遷移策略 (KMP Migration Strategy)

未來的架構將朝向 KMP (Kotlin Multiplatform) 演進：
* **純粹的狀態機**：`BatchProcessor` 中的「跨頁段落續接 (pendingContinuation)」將移交給 KMP。KMP 將作為一個具有狀態的排版引擎，一頁一頁吃進資料，並自動處理跨頁邊界。
* **單一資料源**：iOS 端將退化為「提供圖片」與「提供 CoreML 推論結果」的純 UI/硬體存取層。所有的幾何邏輯 (Top-Left 座標系) 與演算法都在 Kotlin commonMain 中實作。
