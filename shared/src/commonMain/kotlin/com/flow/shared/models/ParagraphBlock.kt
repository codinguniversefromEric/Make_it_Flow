package com.flow.shared.models

data class ParagraphBlock(
    val id: String,
    val role: SemanticRole,
    val unifiedText: String,
    val bounds: NormalizedRect,
    val fragments: List<RichTextFragment>
)
