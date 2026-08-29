package com.flow.shared.models

enum class SemanticRole(val d4laLabel: String) {
    TITLE("Title"),
    HEADING("Section-header"),
    BODY("Text"),
    LIST_ITEM("List-item"),
    CAPTION("Caption"),
    FOOTNOTE("Footnote"),
    FORMULA("Formula"),
    PICTURE("Picture"),
    TABLE("Table"),
    PAGE_HEADER("Page-header"),
    PAGE_FOOTER("Page-footer"),
    UNKNOWN("Unknown")
}
