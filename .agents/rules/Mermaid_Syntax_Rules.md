# Documentation & Mermaid Syntax Guidelines

When generating or modifying Mermaid diagrams (`flowchart`, `sequenceDiagram`, etc.) to be pushed to GitHub or rendered in `README.md`:

1. **Quote Labels with Special Characters**: 
   If a node label contains parentheses `()`, brackets `[]`, or other special characters, you **MUST** enclose the label text in double quotes to prevent GitHub Mermaid parsing errors.
   - ❌ Incorrect: `B{參數解析 (Args)}`
   - ✅ Correct: `B{"參數解析 (Args)"}`
   - ❌ Incorrect: `A[載入資料 [PDF]]`
   - ✅ Correct: `A["載入資料 [PDF]"]`

2. **Always Verify Markdown**: 
   GitHub's Mermaid renderer is strict. Always ensure your syntax is flawless before committing to avoid rendering failures on the repository's main page.
