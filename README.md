# Make it Flow 🌊

**Make it Flow** is a powerful, privacy-first iOS application that transforms any PDF document into a beautifully formatted, highly readable EPUB file. Built with a focus on on-device processing, it ensures your sensitive documents never leave your phone.

![App Header](https://via.placeholder.com/1200x400.png?text=Make+it+Flow)

## 🌟 Key Features

* **100% On-Device Processing**: We value your privacy. No cloud servers, no data collection. All PDF processing is done locally on your iPhone or iPad.
* **Smart Layout Analysis**: Powered by Apple's Vision framework and CoreML (YOLO), the app intelligently identifies titles, body text, tables, images, and captions, effectively reconstructing the document's original reading order.
* **Apple Intelligence / Native LLM Refinement**: Seamlessly fixes broken line breaks, merged paragraphs, and OCR errors using a hybrid approach—leveraging on-device Apple Intelligence where available, or a highly optimized native heuristic engine as a fallback.
* **EPUB Generation**: Outputs standard, clean EPUB files that are perfect for reading on Apple Books, Kindle, or your favorite e-reader.
* **Home Library**: Keep track of all your converted books in a beautiful, grid-based library with generated thumbnails.
* **StoreKit Paywall**: Includes a built-in paywall allowing users 3 free conversions before seamlessly upgrading to a Lifetime or Yearly Pro subscription.

## 📱 Screenshots

*(Add your App Store screenshots here)*

## 🛠️ Tech Stack

* **Language**: Swift 6
* **UI Framework**: SwiftUI
* **Core Technologies**: 
  * `PDFKit` (PDF parsing and thumbnail generation)
  * `Vision` (Native text recognition and bounding box generation)
  * `CoreML` / YOLO (Advanced layout analysis)
  * `StoreKit` (In-App Purchases)

## 🚀 Getting Started

### Prerequisites
* macOS 14.0+
* Xcode 15.0+ (Xcode 16 recommended for Swift 6 features)
* iOS 17.0+ Target Device or Simulator

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/make-it-flow.git
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

## 🧠 Architecture Overview

* **`VisionEngine` & `BatchProcessor`**: The heart of the app. It takes a PDF, converts pages to images, runs YOLO to detect layout blocks (Tables, Figures), and extracts text via PDFKit.
* **`LayoutEngine`**: Implements a horizontal banding algorithm to sort PDF text fragments sequentially, resolving complex multi-column and disjointed paragraph issues.
* **`LLMEngine`**: A text refinement layer that fixes sentence boundaries.
* **`EPUBSynthesizer`**: Compiles the cleaned text, images, and a Table of Contents into a valid EPUB archive.
* **`LibraryStore`**: Manages the persistence of converted EPUBs and thumbnails in the app's document directory using standard JSON encoding.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! 
Feel free to check [issues page](#) if you want to contribute.

## 📝 License

This project is open-source and available under the [MIT License](LICENSE).

---
*Built with ❤️ for a better reading experience.*
