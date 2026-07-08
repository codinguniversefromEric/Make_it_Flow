import Foundation
import AppKit
import CoreGraphics
import CoreText

let filePath = "/Users/giyoshimiken/Documents/Flow_1/Sample_Document.pdf"
let url = URL(fileURLWithPath: filePath)

var mediaBox = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
    print("Failed to create context")
    exit(1)
}

context.beginPDFPage(nil)

// Draw Background
context.setFillColor(gray: 0.98, alpha: 1.0)
context.fill(mediaBox)

// Draw Title
let title = "Make it Flow - Sample Test Document"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 28),
    .foregroundColor: NSColor.black
]
let titleString = NSAttributedString(string: title, attributes: titleAttributes)
let titleLine = CTLineCreateWithAttributedString(titleString)
context.textPosition = CGPoint(x: 50, y: 841.8 - 100)
CTLineDraw(titleLine, context)

// Draw Body
let body = """
Welcome to Make it Flow!

This is a generated test PDF document for the Flow application. 
Make it Flow is designed to take any complex PDF and extract its text beautifully, 
preserving the original reading order, detecting headers, paragraphs, and even 
bypassing messy multi-column layouts using advanced Apple Vision frameworks.

Here are some features you can test with this document:
1. Text extraction accuracy
2. Sentence boundary repair using local LLM
3. EPUB compilation speed and formatting

If you can read this in your EPUB, the conversion was a huge success! 
Enjoy testing your amazing new app.
"""

let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 16),
    .foregroundColor: NSColor.darkGray
]
let bodyString = NSAttributedString(string: body, attributes: bodyAttributes)
let framesetter = CTFramesetterCreateWithAttributedString(bodyString)
let textRect = CGRect(x: 50, y: 100, width: 495.2, height: 600)
let path = CGPath(rect: textRect, transform: nil)
let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)

context.saveGState()
CTFrameDraw(frame, context)
context.restoreGState()

context.endPDFPage()
context.closePDF()

print("PDF generated successfully at: \\(filePath)")
