import sys
import argparse
import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup
import difflib
import html
import re

def extract_text_from_epub(epub_path):
    print(f"Loading EPUB: {epub_path}")
    book = epub.read_epub(epub_path)
    
    text_chunks = []
    
    # Process only spine items (the reading order)
    for item_id, _ in book.spine:
        item = book.get_item_with_id(item_id)
        if item is not None and isinstance(item, ebooklib.epub.EpubHtml):
            # Parse HTML and extract text
            soup = BeautifulSoup(item.get_content(), 'html.parser')
            # Extract text and replace multiple spaces/newlines with a single space
            text = soup.get_text(separator=' ')
            text = re.sub(r'\s+', ' ', text).strip()
            if text:
                text_chunks.append(text)
                
    return " ".join(text_chunks)

def generate_html_diff(text1, text2, output_path):
    print("Generating HTML diff report...")
    d = difflib.SequenceMatcher(None, text1, text2)
    
    html_out = [
        "<!DOCTYPE html>",
        "<html>",
        "<head>",
        "<meta charset='utf-8'>",
        "<title>EPUB Text Diff Report</title>",
        "<style>",
        "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; padding: 20px; color: #333; }",
        ".diff-container { white-space: pre-wrap; word-break: break-word; }",
        ".insert { background-color: #e6ffec; color: #1a7f37; text-decoration: none; }",
        ".delete { background-color: #ffebe9; color: #cf222e; text-decoration: line-through; }",
        ".equal { color: #57606a; }",
        "</style>",
        "</head>",
        "<body>",
        "<h2>EPUB Text Difference Report</h2>",
        "<p><strong>Legend:</strong></p>",
        "<ul>",
        "<li><span class='delete'>Red (Strikethrough)</span>: Text present in Generated EPUB but NOT in GT (Possible Noise/Injected Headers).</li>",
        "<li><span class='insert'>Green</span>: Text present in GT EPUB but NOT in Generated (Possible Missing Text).</li>",
        "<li><span class='equal'>Grey</span>: Matching text.</li>",
        "</ul>",
        "<hr>",
        "<div class='diff-container'>"
    ]
    
    # For large texts, difflib can be slow. 
    # We will process opcodes to generate HTML.
    for tag, i1, i2, j1, j2 in d.get_opcodes():
        if tag == 'equal':
            # Grey text
            html_out.append(f"<span class='equal'>{html.escape(text1[i1:i2])}</span>")
        elif tag == 'delete':
            # Present in text1 (generated) but missing in text2 (GT) -> Noise
            html_out.append(f"<span class='delete'>{html.escape(text1[i1:i2])}</span>")
        elif tag == 'insert':
            # Missing in text1 (generated) but present in text2 (GT) -> Missed text
            html_out.append(f"<span class='insert'>{html.escape(text2[j1:j2])}</span>")
        elif tag == 'replace':
            # Both changed
            html_out.append(f"<span class='delete'>{html.escape(text1[i1:i2])}</span>")
            html_out.append(f"<span class='insert'>{html.escape(text2[j1:j2])}</span>")
            
    html_out.append("</div></body></html>")
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("".join(html_out))
    
    print(f"Diff report saved to {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Compare Generated EPUB with Ground Truth EPUB.")
    parser.add_argument("--generated", required=True, help="Path to the generated EPUB file")
    parser.add_argument("--gt", required=True, help="Path to the Ground Truth EPUB file")
    parser.add_argument("--out", required=True, help="Path for the output HTML report")
    
    args = parser.parse_args()
    
    generated_text = extract_text_from_epub(args.generated)
    gt_text = extract_text_from_epub(args.gt)
    
    print(f"Extracted {len(generated_text)} chars from Generated EPUB.")
    print(f"Extracted {len(gt_text)} chars from GT EPUB.")
    
    generate_html_diff(generated_text, gt_text, args.out)

if __name__ == '__main__':
    main()
