package com.flow.shared.models

data class LayoutBlock(
    val id: String,
    val bounds: NormalizedRect,
    val role: SemanticRole,
    val confidence: Float
)
