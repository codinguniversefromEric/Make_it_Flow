package com.flow.shared.core

import com.flow.shared.models.LayoutBlock
import com.flow.shared.models.NormalizedRect
import com.flow.shared.models.RichTextFragment
import com.flow.shared.models.SemanticRole
import kotlin.test.Test
import kotlin.test.assertEquals

class HybridCorrectorTest {
    @Test
    fun testFallbackForLeakage() {
        val yoloBlocks = listOf(
            LayoutBlock(
                id = "b1",
                bounds = NormalizedRect(0.1, 0.1, 0.8, 0.2),
                role = SemanticRole.TITLE,
                confidence = 0.9f
            )
        )
        
        val fragments = listOf(
            RichTextFragment("f1", "Main Title", NormalizedRect(0.15, 0.15, 0.5, 0.1), 24.0, true, false, "#000000"),
            // Leaked fragment! Outside the bounding box of b1
            RichTextFragment("f2", "Subtitle (Missed)", NormalizedRect(0.1, 0.4, 0.5, 0.1), 14.0, false, false, "#555555")
        )
        
        val result = HybridCorrector.process(yoloBlocks, fragments)
        
        assertEquals(2, result.size, "Should recover the leaked fragment as a fallback block")
        
        val fallback = result.find { it.id.startsWith("fallback") }
        assertEquals(SemanticRole.BODY, fallback?.role, "Fallback should default to BODY")
        assertEquals("Subtitle (Missed)", fallback?.unifiedText)
    }
}
