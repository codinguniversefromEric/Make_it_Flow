---
description: 關於 Apple Vision 框架與 KMP 的幾何座標轉換規範
---

# Vision Coordinate 座標系統轉換規範

這是一條**強制性**的開發規則。未來所有的 AI 代理在處理 bounding box、排版幾何與 YOLO 輸出時，都必須嚴格遵守以下座標系統的定義與轉換公式。

## 背景陷阱 (The Trap)
Apple 的 `Vision` 框架 (以及 CoreML 的部分輸出) 採用的座標系與傳統 UI 完全不同：
* **Vision 座標系**：原點 `(0, 0)` 在螢幕的**左下角 (Bottom-Left)**，向上 Y 增加。而且是 `[0, 1]` 的正規化數值。
* **UI / KMP 座標系**：原點 `(0, 0)` 在螢幕的**左上角 (Top-Left)**，向下 Y 增加。

如果不做反轉直接使用，所有的文字與排版框都會發生「上下顛倒」的致命錯誤。

## 開發規範 (Rules)

1. **Y 軸反轉公式**
   將 Vision 的 `normalizedRect` 轉為 KMP/UI 可用的座標時，必須進行 Y 軸反轉：
   ```swift
   // 錯誤寫法 (會上下顛倒)：
   // let y = normalizedRect.minY * pageHeight
   
   // 正確寫法：
   let y = (1.0 - normalizedRect.maxY) * pageHeight
   ```

2. **DocLayout-YOLO 1024x1024 映射**
   我們使用的 DocLayout-YOLO 模型輸入為 `1024x1024`。
   當使用 Vision 的 `.scaleFit` 模式將長方形 PDF 塞入 `1024x1024` 時，Vision 會自動加上上下或左右的 Padding (黑邊)。
   模型輸出 (NMS-Free tensor) 的座標是基於有 padding 的 `1024x1024`，因此：
   - **嚴禁**直接將 YOLO 的絕對座標除以 1024 就當作正規化座標。
   - **必須**先扣除 Padding，並根據實際影像的比例縮放，才能還原為 PDF 上的真實座標。

3. **統一在 KMP 處理**
   未來 iOS 端只負責將 CoreML 產生的框「轉成 Top-Left 正規化」後，丟給 KMP。所有幾何吸附 (Midpoint/IoU) 與排序演算法，一律在 KMP 內使用 Top-Left 座標系進行。
