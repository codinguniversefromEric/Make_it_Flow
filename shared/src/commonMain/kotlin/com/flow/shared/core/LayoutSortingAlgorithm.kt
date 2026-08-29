package com.flow.shared.core

import com.flow.shared.models.ParagraphBlock

object LayoutSortingAlgorithm {
    /**
     * Topologically sorts paragraph blocks by human reading order.
     */
    fun sort(blocks: List<ParagraphBlock>): List<ParagraphBlock> {
        return blocks.sortedWith(Comparator { a, b ->
            // If they are roughly on the same line (within 2% of page height)
            if (kotlin.math.abs(a.bounds.y - b.bounds.y) < 0.02) {
                a.bounds.x.compareTo(b.bounds.x)
            } else {
                a.bounds.y.compareTo(b.bounds.y)
            }
        })
    }
}
