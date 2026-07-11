# Make it Flow 🌊

**Make it Flow** is a powerful, privacy-first iOS application that transforms any PDF document into a beautifully formatted, highly readable EPUB file. Built with a focus on on-device processing, it ensures your sensitive documents never leave your phone.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/tw/app/make-it-flow/id6780764422?l=en-GB)

<img width="35%" height="1024" alt="Untitled (Copy)" src="https://github.com/user-attachments/assets/673a3de1-06a7-4769-aa28-d3e541982040" />

## 🌟 Key Features

* **100% On-Device Processing**: We value your privacy. No cloud servers, no data collection. All PDF processing is done locally on your iPhone or iPad.
* **Smart Layout Analysis**: Powered by Apple's Vision framework and CoreML (YOLO), the app intelligently identifies titles, body text, tables, images, and captions, effectively reconstructing the document's original reading order.
* **Apple Intelligence / Native LLM Refinement**: Seamlessly fixes broken line breaks, merged paragraphs, and OCR errors using a hybrid approach—leveraging on-device Apple Intelligence where available, or a highly optimized native heuristic engine as a fallback.
* **EPUB Generation**: Outputs standard, clean EPUB files that are perfect for reading on Apple Books, Kindle, or your favorite e-reader.
* **Home Library**: Keep track of all your converted books in a beautiful, grid-based library with generated thumbnails.
* **StoreKit Paywall**: Includes a built-in paywall allowing users 3 free conversions before seamlessly upgrading to a Lifetime or Yearly Pro subscription.
* **AdMob Monetization**: Integrated with Google Mobile Ads (Native & Interstitial) for freemium users, complete with a beautifully customized, premium native ad UI that seamlessly blends into the app. Pro users enjoy a 100% ad-free experience.

## 📱 Demo

https://github.com/user-attachments/assets/96e65142-16ab-4966-ba22-0ead609a3662



## 🛠️ Tech Stack

* **Language**: Swift 6
* **UI Framework**: SwiftUI
* **Core Technologies**: 
  * `PDFKit` (PDF parsing and thumbnail generation)
  * `Vision` (Native text recognition and bounding box generation)
  * `CoreML` / YOLO (Advanced layout analysis)
  * `StoreKit` (In-App Purchases)
  * `GoogleMobileAds` (AdMob Native & Interstitial Ads)

## 🚀 Getting Started

### Prerequisites
* macOS 14.0+
* Xcode 15.0+ (Xcode 16 recommended for Swift 6 features)
* iOS 17.0+ Target Device or Simulator

### Installation

1. Clone this repository:
   ```bash
   https://github.com/codinguniversefromEric/Make_it_Flow.git
   ```
2. Open `Flow_1.xcodeproj` in Xcode.
3. Select your desired simulator or connected iOS device.
4. Hit `Cmd + R` to build and run the app.

### Testing In-App Purchases (StoreKit)

The app comes with a local StoreKit configuration to test the paywall without needing an App Store Connect setup.

1. In Xcode, click on the **Scheme Name (Flow_1)** at the top toolbar and select **Edit Scheme...**
2. Select **Run** from the left sidebar, and click the **Options** tab.
3. Under **StoreKit Configuration**, select `Flow_1.storekit`.
4. Run the app. You can now test the paywall freely in the local environment!

## 📊 Model Benchmark & Comparison

To understand the trade-offs between different models tested during the development of this app, here is a comparison of Document Layout Analysis (DLA) models:

| Model | Framework | Size | Inference Time (M2) | Strengths / Trade-offs |
|-------|-----------|------|-----------------------------------|-----------|
| **YOLOv8n (Fast)** | CoreML | ~12MB | Ultra-fast (< 50ms) | Extremely lightweight. Good for mobile apps. Detects basic text, titles, and headers well. |
| **YOLOv8s (Standard)** | CoreML | ~22MB | Fast (~80ms) | The most stable and robust model for layout detection in real-world complex PDFs. Highly recommended. |
| **YOLOv10s (DocLayNet)** | CoreML | ~31MB | Fast (~90ms) | Newer architecture (NMS-free), but practically struggles with some edge cases in sorting compared to the standard YOLOv8s. |
| **Marker Pipeline** | PyTorch/ONNX | > 1GB | Slow (Desktop/Cloud) | State-of-the-Art accuracy. End-to-end pipeline generating full markdown with perfect formula parsing, but too heavy for iOS on-device. |

*Note: Make it Flow intentionally chooses the CoreML YOLO models to guarantee fast, 100% on-device offline processing without draining the battery.*

## 🧠 Architecture Overview

* **`VisionEngine` & `BatchProcessor`**: The heart of the app. It takes a PDF, converts pages to images, runs YOLO to detect layout blocks (Tables, Figures), and extracts text via PDFKit.
* **`LayoutEngine`**: Implements a horizontal banding algorithm to sort PDF text fragments sequentially, resolving complex multi-column and disjointed paragraph issues.
* **`LLMEngine`**: A text refinement layer that fixes sentence boundaries.
* **`EPUBSynthesizer`**: Compiles the cleaned text, images, and a Table of Contents into a valid EPUB archive.
* **`LibraryStore`**: Manages the persistence of converted EPUBs and thumbnails in the app's document directory using standard JSON encoding.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! 
Feel free to check [issues page](#) if you want to contribute.

## ⚖️ License & Third-Party Credits

This project is open-source and licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**. 

### Third-Party Models & Framework Credits
To power the on-device layout analysis, **Make it Flow** utilizes the following open-source components:
1. **CoreML / YOLO Framework**: Powered by [Ultralytics YOLOv8](https://github.com), which is licensed under the AGPL-3.0.
2. **Document Layout Model**: Uses the pre-trained weights from [vaivTA/yolov8n_doclaynet](https://huggingface.co) developed by **VAIV-TA-LAB**.
3. **Document Structure Model**: Uses the pre-trained weights from [ashen007/document-structure-detection](https://huggingface.co) (`DSD-YOLOv8-v2.pt`).

All specialized model weights mentioned above are fine-tuned on top of the Ultralytics YOLOv8 architecture, and this project's licensing strictly adheres to its copyleft requirements.

### ⚠️ Trademark & Asset Notice
While the source code and model architectures are freely available under the AGPL-3.0, the **"Make it Flow"** brand name, application icon, user interface (UI/UX) visual design, and related branding assets are the exclusive intellectual property of the author. 

**You are NOT permitted** to use the "Make it Flow" name, logos, or original app icons to repackage, clone, or redistribute this application to the Apple App Store, Google Play Store, or any other commercial marketplace without explicit written permission.

---
*Built with ❤️ for a better reading experience.*
