import sys
import CoreGraphics as CG
import CoreText as CT
import Foundation as NS

def create_pdf(file_path):
    # PDF dimensions (A4 size)
    width, height = 595.2, 841.8
    page_rect = CG.CGRectMake(0, 0, width, height)

    url = NS.NSURL.fileURLWithPath_(file_path)
    context = CG.CGPDFContextCreateWithURL(url, page_rect, None)

    CG.CGPDFContextBeginPage(context, None)
    
    # Draw background
    CG.CGContextSetRGBFillColor(context, 0.98, 0.98, 0.98, 1.0)
    CG.CGContextFillRect(context, page_rect)

    # Title
    title = "Make it Flow - Sample Document"
    title_attr = {
        NS.NSFontAttributeName: NS.NSFont.systemFontOfSize_weight_(28.0, 0.5), # Bold
        NS.NSForegroundColorAttributeName: NS.NSColor.blackColor()
    }
    title_str = NS.NSAttributedString.alloc().initWithString_attributes_(title, title_attr)
    title_line = CT.CTLineCreateWithAttributedString(title_str)
    
    CG.CGContextSetTextPosition(context, 50, height - 100)
    CT.CTLineDraw(title_line, context)

    # Body text
    body = """
    Welcome to Make it Flow!

    This is a sample PDF document generated automatically to test the Flow application. 
    Make it Flow is designed to take any complex PDF and extract its text beautifully, 
    preserving the original reading order, detecting headers, paragraphs, and even 
    bypassing messy multi-column layouts using advanced Apple Vision frameworks.

    Here are some features you can test with this document:
    1. Text extraction accuracy
    2. Sentence boundary repair using local LLM
    3. EPUB compilation speed and formatting

    Enjoy testing your amazing new app!
    """
    
    body_attr = {
        NS.NSFontAttributeName: NS.NSFont.systemFontOfSize_(14.0),
        NS.NSForegroundColorAttributeName: NS.NSColor.darkGrayColor()
    }
    body_str = NS.NSAttributedString.alloc().initWithString_attributes_(body, body_attr)
    
    # Text box (using framesetter for multi-line)
    framesetter = CT.CTFramesetterCreateWithAttributedString(body_str)
    text_rect = CG.CGRectMake(50, 400, width - 100, height - 200)
    path = CG.CGPathCreateWithRect(text_rect, None)
    frame = CT.CTFramesetterCreateFrame(framesetter, CG.CFRangeMake(0, 0), path, None)

    CT.CTFrameDraw(frame, context)

    CG.CGPDFContextEndPage(context)
    CG.CGPDFContextClose(context)
    print(f"Created PDF at: {file_path}")

if __name__ == '__main__':
    create_pdf('Sample_Document.pdf')
