package com.flow.shared.core

import com.flow.shared.models.LayoutBlock
import com.flow.shared.models.RichTextFragment
import com.flow.shared.models.ParagraphBlock
import com.flow.shared.models.SemanticRole
import com.flow.shared.models.NormalizedRect

object HybridCorrector {
    /**
     * Cross-references YOLO layout blocks with PDFKit rich text fragments.
     * Prevents leakage (texts missed by YOLO) by using geometric fallbacks for unassigned fragments.
     */
    fun process(
        blocks: List<LayoutBlock>, 
        fragments: List<RichTextFragment>
    ): List<ParagraphBlock> {
        val blockMap = mutableMapOf<String, MutableList<RichTextFragment>>()
        val unassigned = mutableListOf<RichTextFragment>()

        for (frag in fragments) {
            val matchedBlock = blocks.find { block ->
                val intersection = block.bounds.intersectionArea(frag.bounds)
                // Overlap > 40% or center point inside
                intersection / frag.bounds.area > 0.4 || 
                (frag.bounds.midX >= block.bounds.x && frag.bounds.midX <= block.bounds.maxX &&
                 frag.bounds.midY >= block.bounds.y && frag.bounds.midY <= block.bounds.maxY)
            }

            if (matchedBlock != null) {
                blockMap.getOrPut(matchedBlock.id) { mutableListOf() }.add(frag)
            } else {
                unassigned.add(frag)
            }
        }

        val result = mutableListOf<ParagraphBlock>()
        
        for (block in blocks) {
            val blockFrags = blockMap[block.id] ?: continue
            if (blockFrags.isEmpty()) continue
            
            // Sort top-down
            blockFrags.sortBy { it.bounds.y }
            
            val unifiedText = blockFrags.joinToString(" ") { it.text }
            result.add(
                ParagraphBlock(
                    id = block.id,
                    role = block.role,
                    unifiedText = unifiedText,
                    bounds = block.bounds,
                    fragments = blockFrags
                )
            )
        }

        // Geometric fallback for unassigned fragments (Anti-leakage)
        if (unassigned.isNotEmpty()) {
            unassigned.sortBy { it.bounds.y }
            var currentFrags = mutableListOf<RichTextFragment>()
            var lastY = unassigned.first().bounds.maxY
            
            for (i in 0 until unassigned.size) {
                val frag = unassigned[i]
                if (frag.bounds.y - lastY > 0.05) { // 5% page height gap
                    if (currentFrags.isNotEmpty()) {
                        result.add(createFallbackBlock(currentFrags))
                        currentFrags = mutableListOf()
                    }
                }
                currentFrags.add(frag)
                lastY = frag.bounds.maxY
            }
            if (currentFrags.isNotEmpty()) {
                result.add(createFallbackBlock(currentFrags))
            }
        }

        return result
    }
    
    private fun createFallbackBlock(fragments: List<RichTextFragment>): ParagraphBlock {
        val minX = fragments.minOf { it.bounds.x }
        val minY = fragments.minOf { it.bounds.y }
        val maxX = fragments.maxOf { it.bounds.maxX }
        val maxY = fragments.maxOf { it.bounds.maxY }
        
        return ParagraphBlock(
            id = "fallback-${fragments.first().id}",
            role = SemanticRole.BODY, // Fallback defaults to body
            unifiedText = fragments.joinToString(" ") { it.text },
            bounds = NormalizedRect(minX, minY, maxX - minX, maxY - minY),
            fragments = fragments
        )
    }
}
