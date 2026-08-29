---
description: EPUB 封裝與合規性規範
---

# EPUB 封裝與 XML 合規性規範

這是一條**強制性**的開發規則。未來任何涉及修改 `EPUBSynthesizer`、調整匯出格式、或升級書籍樣式的 AI 代理，都必須嚴格遵守以下合規性要求。否則產出的 `.epub` 將會被 Apple Books 或 Thorium Reader 拒絕開啟。

## 1. ZIP 封裝規範 (The StoredZIPArchive Rule)
EPUB 檔案本質上是一個 ZIP 壓縮檔，但它有非常嚴格的規範：
* **`mimetype` 必須是第一個檔案**。
* **`mimetype` 檔案絕對不可以壓縮 (Compression Method 必須為 0 / Stored)**。
* **`mimetype` 檔案不能包含任何 Extra Field**。

**行動指南**：
專案內已經實作了純 Swift 的 `StoredZIPArchive`。嚴禁未來為了「縮小檔案體積」而引入標準的 ZIP 壓縮演算法來壓縮 `mimetype`。

## 2. XML 禁忌字元清洗 (XML Sanitization)
EPUB 的章節內容是 XHTML (基於 XML)。XML 1.0 對於控制字元非常敏感。
PDF 萃取出來的文字，經常包含看不見的非法控制碼 (如 `\u{0000}` ~ `\u{001F}`)。

**行動指南**：
* 寫入 XHTML 前，必須呼叫 `removeInvalidXMLCharacters()`。
* 任何可能包含 `<`、`>`、`&` 的純文字內容 (如 `<title>` 或 TOC 內的標題)，必須被轉義為 `&lt;`、`&gt;`、`&amp;`。

## 3. 強制自閉合標籤 (Self-Closing Tags)
XHTML 比 HTML5 嚴格得多。
* `<br>` 必須寫成 `<br/>`
* `<hr>` 必須寫成 `<hr/>`
* `<img>` 標籤必須自閉合：`<img src="..." alt="..."/>`
如果 Markdown parser (如 Ink) 產出的是鬆散的 HTML5，我們必須透過 Regex 將其強制轉為合規的 XHTML。
