package com.flow.shared.models

data class RichTextFragment(
    val id: String,
    val text: String,
    val bounds: NormalizedRect,
    val fontSize: Double,
    val isBold: Boolean,
    val isItalic: Boolean,
    val colorHex: String // e.g. "#FF0000"
)
