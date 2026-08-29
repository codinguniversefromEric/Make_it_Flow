# Documentation & Mermaid Syntax Guidelines

## 1. Language Policy (English Only)
To maintain the professional and international standard of this open-source project, the **`README.md` must be written entirely in English**. No bilingual or Traditional Chinese text should be included in the public README.

## 2. Mermaid Diagram Standard (DFD/UML Shapes)
When creating or modifying `flowchart` or `sequenceDiagram` in Mermaid:
- **Strict Shapes**: You must use correct DFD / UML shapes for nodes:
  - `[ ]` (Rectangle) for Processes / Engines / Functions
  - `[/ /]` (Parallelogram) for Data Input/Output (I/O)
  - `[( )]` (Cylinder) for Data Storage / Databases / Final File Output
  - `([ ])` (Pill) for Terminal / Start / End 
  - `{ }` (Diamond) for Decisions / Branches
- **Colors Permitted**: Applying `style` to nodes to highlight key components (e.g., core engine, inputs, outputs) is highly encouraged to make the flowchart visually appealing.
- **Quote Special Characters**: If a node label contains parentheses `()`, brackets `[]`, or other special characters, you MUST enclose the label text in double quotes to prevent GitHub Mermaid parsing errors.
  - ❌ Incorrect: `B{參數解析 (Args)}`
  - ✅ Correct: `B{"參數解析 (Args)"}`
