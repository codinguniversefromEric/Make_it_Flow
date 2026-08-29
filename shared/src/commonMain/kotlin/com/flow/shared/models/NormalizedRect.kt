package com.flow.shared.models

/**
 * Normalised coordinates (0.0 to 1.0).
 * By our system rules:
 * - Origin (0,0) is at the TOP-LEFT of the page.
 * - y increases downwards.
 * - This matches standard UI coordinate systems and EPUBSpecs.
 */
data class NormalizedRect(
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double
) {
    val maxX: Double get() = x + width
    val maxY: Double get() = y + height
    val midX: Double get() = x + width / 2
    val midY: Double get() = y + height / 2

    fun intersectionArea(other: NormalizedRect): Double {
        val minX = maxOf(x, other.x)
        val minY = maxOf(y, other.y)
        val maxX = minOf(this.maxX, other.maxX)
        val maxY = minOf(this.maxY, other.maxY)

        val w = maxOf(0.0, maxX - minX)
        val h = maxOf(0.0, maxY - minY)
        return w * h
    }

    val area: Double get() = width * height
}
