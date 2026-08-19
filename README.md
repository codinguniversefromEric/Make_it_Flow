# Make it Flow 🌊

**Make it Flow** 是一款主打隱私優先的 iOS 應用程式，能將任何 PDF 文件轉換為排版精美、高度可讀的 EPUB 檔案。專注於裝置端 (On-device) 處理，確保您的機密文件絕對不會外流到雲端。

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/tw/app/make-it-flow/id6780764422?l=en-GB)

<img width="35%" height="1024" alt="Untitled (Copy)" src="https://github.com/user-attachments/assets/673a3de1-06a7-4769-aa28-d3e541982040" />

## 🌟 核心功能

* **100% 裝置端處理 (On-Device)**：我們重視您的隱私，沒有雲端伺服器，不收集資料。所有的 PDF 解析都在您的 iPhone 或 iPad 上本地執行。
* **智慧版面分析 (Smart Layout Analysis)**：基於 Apple 的 Vision 框架與 CoreML (YOLO)，App 能聰明地辨識標題、內文、表格、圖片與圖說，完美重建文件原本的閱讀順序。
* **Apple Intelligence / 原生 LLM 潤飾**：無縫修復斷行錯誤、段落合併與 OCR 錯誤。採用混合式策略——在支援的裝置上使用 Apple Intelligence，否則退回使用高度優化的原生啟發式引擎。
* **EPUB 產生器**：輸出標準且乾淨的 EPUB 檔案，完美適配 Apple Books、Kindle 或您最愛的電子書閱讀器。
* **本地書庫 (Home Library)**：透過美觀的網格狀書庫與自動產生的縮圖，管理您所有轉換完成的書籍。

> 💡 **開源友善化聲明**：為了讓開發者更容易上手與編譯，我們已於最新版本中**移除所有廣告 (AdMob) 與內購 (StoreKit) 相關程式碼**，讓您不需煩惱繁瑣的憑證設定即可本地執行！

## 🚀 新手上路 (Getting Started)

### 環境需求
* macOS 14.0+
* Xcode 15.0+ (強烈建議使用 Xcode 16 以支援 Swift 6)
* iOS 17.0+ 實體裝置或模擬器

### 安裝與執行 (一鍵下載 Model)

1. Clone 本專案：
   ```bash
   git clone https://github.com/codinguniversefromEric/Make_it_Flow.git
   cd Make_it_Flow
   ```
2. **自動下載必需的 CoreML Models**：
   由於模型檔案較大，我們未將其放入 Git。請在終端機執行以下腳本，它會自動透過 HuggingFace API 將缺少的 `.mlpackage` 下載並放置到 `Flow_1/Models` 資料夾：
   ```bash
   sh scripts/download_models.sh
   ```
   *(註：下載完成後，請確認這些 `.mlpackage` 有被正確加入 Xcode 的 `Flow_1` Target 中)*
3. 在 Xcode 中開啟 `Flow_1.xcodeproj`。
4. 選擇您的模擬器或 iOS 裝置，按下 `Cmd + R` 即可編譯執行！

## 🧠 架構總覽與資料流 (Architecture & Data Flow)

為了方便未來的維護者與開源貢獻者快速理解系統，以下是從 PDF 匯入到 EPUB 產出的生命週期：

```mermaid
flowchart TD
    A[使用者匯入 PDF] --> B(VisionEngine & BatchProcessor)
    
    subgraph Core Processing
    B -->|Image + Text| C(YOLO Model 推論)
    C -->|Bounding Boxes| D(LayoutEngine)
    D -->|排序後的文字與圖塊| E(LLMEngine)
    end
    
    E -->|語意修復後的純文字| F(EPUBSynthesizer)
    F -->|EPUB 封裝檔| G[LibraryStore]
    G --> H[呈現在 UI 書庫]

    style Core Processing fill:#f9f9f9,stroke:#333,stroke-width:2px
```

### 核心模組 I/O 定義
* **`VisionEngine` & `BatchProcessor`**: 系統核心。將 PDF 轉為圖片後，透過 YOLO 找出排版區塊 (Tables, Figures)，同時透過 PDFKit 擷取原生文字。
  - **Input**: `PDF Page` (URL 或 Data)
  - **Output**: `[BoundingBox, Raw Text]`
* **`LayoutEngine`**: 實作水平帶狀掃描演算法 (Horizontal banding algorithm)，解決多欄位與複雜段落的文字順序問題。
  - **Input**: `[BoundingBox, Raw Text]`
  - **Output**: `Sorted Text Blocks`
* **`LLMEngine`**: 文字潤飾層，負責修復斷字與句子邊界。
  - **Input**: `Sorted Text Blocks`
  - **Output**: `Refined Markdown/Text`
* **`EPUBSynthesizer`**: 將清理後的文字、圖片與目錄 (TOC) 組裝成合法的 EPUB 檔案。
* **`LibraryStore`**: 管理轉換好的 EPUB 及其縮圖，使用標準 JSON 編碼儲存於 App 的 Document Directory。

## 📊 模型效能指標 (Model Benchmark & Metrics)

在開發期間，我們測試了多種 Document Layout Analysis (DLA) 模型，以下是我們在 **Hugging Face `datalab-to/marker_benchmark`** 的測試與決策依據，保留於此以供未來參考：

| 模型 / 解決方案 | 框架 | 推論時間 | Benchmark 表現 (Normalized Edit Distance) | 優勢與權衡 |
|-------|-----------|------------------|---------------------------|-----------|
| **YOLOv8s (Standard) + Native Text** | CoreML | **~2.0s / doc** | **~86% - 96%** | **本專案採用的混合方案**。100% 裝置端運算。結合原生 PDF 文字層與 YOLO 版面分析，能在 M 系列晶片上達到與大型模型相仿的精準度，且只需幾秒鐘。 |
| **YOLOv10s (DocLayNet)** | CoreML | 極快 | N/A | 較新的架構 (免 NMS)，但在部分文字排序與區塊交集邊緣案例上的表現，暫時不如標準 YOLOv8s。 |
| **Marker Pipeline** | PyTorch/ONNX | > 30s / doc | ~90% - 98% | State-of-the-Art 精準度。能生成完美的 Markdown 與公式，但模型重達 >1GB，對 iOS 裝置來說負擔太大且過於緩慢。 |

*註：Make it Flow 刻意選擇 CoreML YOLO 結合原生 PDF 提取，以確保極速、省電且完全離線的裝置端體驗。*

## 🤝 貢獻與贊助 (Contributing & Support)

我們非常歡迎任何 Issue 或是 Pull Request！如果您對這個專案感興趣，歡迎直接參與貢獻。

如果您覺得這個專案對您有幫助，且希望能支持開發者持續維護，歡迎透過 GitHub Sponsors 贊助我們：
💖 **[Donate (GitHub Sponsors)](https://github.com/codinguniversefromEric/Make_it_Flow.git)**
*(註：作者並不追求以此獲利，您的隨喜贊助將成為專案持續更新的動力)*

## ⚖️ 授權與第三方致謝

本專案為開源軟體，採用 **GNU Affero General Public License v3.0 (AGPL-3.0)** 授權。

### 模型與框架致謝
1. **CoreML / YOLO Framework**: 基於 [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics) (AGPL-3.0)。
2. **Document Layout Model**: 使用來自 **VAIV-TA-LAB** 的 [vaivTA/yolov8n_doclaynet](https://huggingface.co/vaivTA/yolov8n_doclaynet) 預訓練權重。
3. **Document Structure Model**: 使用 [ashen007/document-structure-detection](https://huggingface.co/ashen007/document-structure-detection) (`DSD-YOLOv8-v2.pt`) 的預訓練權重。

### ⚠️ 商標與資產聲明
雖然程式碼與模型架構依循 AGPL-3.0 免費釋出，但 **"Make it Flow"** 的品牌名稱、App Icon、UI/UX 視覺設計及相關品牌資產，皆為作者專屬之智慧財產。
**未經明確書面授權，禁止**使用 "Make it Flow" 之名稱、標誌或原版 App Icon 重新包裝、上架至 Apple App Store 或任何商業市場。

---
*Built with ❤️ for a better reading experience.*
