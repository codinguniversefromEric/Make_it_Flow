package com.flow.shared.core

import com.flow.shared.models.ParagraphBlock
import com.flow.shared.models.SemanticRole

object MetadataExtractor {
    /**
     * Attempts to extract the title of the document.
     * Uses YOLO's TITLE role if available. 
     * Otherwise, falls back to finding the text block with the largest font size.
     */
    fun extractTitle(blocks: List<ParagraphBlock>): String? {
        val titleBlock = blocks.firstOrNull { it.role == SemanticRole.TITLE }
        if (titleBlock != null) return titleBlock.unifiedText

        return blocks.maxByOrNull { block -> 
            block.fragments.maxOfOrNull { it.fontSize } ?: 0.0 
        }?.unifiedText
    }
}
