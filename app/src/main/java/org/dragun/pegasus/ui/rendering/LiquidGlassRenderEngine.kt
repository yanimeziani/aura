package org.dragun.pegasus.ui.rendering

import android.graphics.*
import android.view.View
import androidx.annotation.FloatRange
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.*

/**
 * High-performance Kotlin render engine for liquid glass visual effects
 * Optimized for iOS 16 1:1 design patterns on Android
 */
class LiquidGlassRenderEngine {
    
    companion object {
        // Performance optimization constants
        private const val MAX_BLUR_RADIUS = 25f
        private const val GLASS_ALPHA_RANGE = 0.05f..0.25f
        private const val ANIMATION_DURATION_MS = 300
        private const val SPRING_DAMPENING = 0.8f
        private const val SPRING_STIFFNESS = 400f
        
        // iOS 16 specific constants
        private const val IOS_CORNER_RADIUS_SMALL = 12f
        private const val IOS_CORNER_RADIUS_MEDIUM = 16f
        private const val IOS_CORNER_RADIUS_LARGE = 24f
        private const val IOS_SHADOW_ELEVATION = 8f
        
        // Glass effect parameters
        private const val GLASS_NOISE_INTENSITY = 0.03f
        private const val GLASS_REFLECTION_INTENSITY = 0.15f
        private const val GLASS_REFRACTION_STRENGTH = 0.02f
    }
    
    /**
     * Advanced glass material properties matching iOS 16 specifications
     */
    data class GlassMaterial(
        val baseColor: Color = Color.White,
        @FloatRange(from = 0.0, to = 1.0) val transparency: Float = 0.15f,
        @FloatRange(from = 0.0, to = 1.0) val blurStrength: Float = 0.8f,
        @FloatRange(from = 0.0, to = 1.0) val reflectionIntensity: Float = GLASS_REFLECTION_INTENSITY,
        @FloatRange(from = 0.0, to = 1.0) val refractionStrength: Float = GLASS_REFRACTION_STRENGTH,
        val borderWidth: Dp = 1.dp,
        val cornerRadius: Dp = IOS_CORNER_RADIUS_MEDIUM.dp,
        val shadowElevation: Dp = IOS_SHADOW_ELEVATION.dp,
        val enableNoise: Boolean = true,
        val enableReflections: Boolean = true
    )
    
    /**
     * Liquid animation state for dynamic glass effects
     */
    data class LiquidAnimationState(
        val waveAmplitude: Float = 0.0f,
        val waveFrequency: Float = 1.0f,
        val flowDirection: Float = 0.0f,
        val rippleIntensity: Float = 0.0f,
        val timeOffset: Float = 0.0f
    )
    
    /**
     * Performance-optimized glass rendering with hardware acceleration
     */
    @Composable
    fun renderLiquidGlass(
        modifier: Modifier = Modifier,
        material: GlassMaterial = GlassMaterial(),
        animationState: LiquidAnimationState = LiquidAnimationState(),
        isPressed: Boolean = false,
        isHovered: Boolean = false,
        content: @Composable () -> Unit = {}
    ) {
        val density = LocalDensity.current
        
        // Animated properties for interaction feedback
        val scale by animateFloatAsState(
            targetValue = when {
                isPressed -> 0.97f
                isHovered -> 1.02f
                else -> 1.0f
            },
            animationSpec = spring(
                dampingRatio = SPRING_DAMPENING,
                stiffness = SPRING_STIFFNESS
            ),
            label = "glass_scale"
        )
        
        val glassAlpha by animateFloatAsState(
            targetValue = when {
                isPressed -> material.transparency + 0.1f
                isHovered -> material.transparency + 0.05f
                else -> material.transparency
            }.coerceIn(GLASS_ALPHA_RANGE),
            animationSpec = spring(
                dampingRatio = SPRING_DAMPENING,
                stiffness = SPRING_STIFFNESS
            ),
            label = "glass_alpha"
        )
        
        val blurRadius by animateFloatAsState(
            targetValue = (material.blurStrength * MAX_BLUR_RADIUS) *
                if (isPressed) 1.2f else 1.0f,
            animationSpec = spring(
                dampingRatio = SPRING_DAMPENING,
                stiffness = SPRING_STIFFNESS
            ),
            label = "blur_radius"
        )
        
        // Time-based animation for liquid effects
        val animationTime by animateFloatAsState(
            targetValue = animationState.timeOffset + 1000f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 10000, easing = LinearEasing)
            ),
            label = "liquid_time"
        )
        
        Box(
            modifier = modifier
                .scale(scale)
                .drawWithCache {
                    val path = Path().apply {
                        addRoundRect(
                            RoundRect(
                                rect = androidx.compose.ui.geometry.Rect(
                                    offset = Offset.Zero,
                                    size = size
                                ),
                                cornerRadius = CornerRadius(
                                    x = with(density) { material.cornerRadius.toPx() },
                                    y = with(density) { material.cornerRadius.toPx() }
                                )
                            )
                        )
                    }
                    
                    onDrawBehind {
                        drawGlassEffect(
                            path = path,
                            material = material.copy(transparency = glassAlpha),
                            animationState = animationState.copy(timeOffset = animationTime),
                            blurRadius = blurRadius,
                            density = density
                        )
                    }
                }
        ) {
            content()
        }
    }
    
    /**
     * Core glass effect rendering with advanced shaders and lighting
     */
    private fun DrawScope.drawGlassEffect(
        path: Path,
        material: GlassMaterial,
        animationState: LiquidAnimationState,
        blurRadius: Float,
        density: Density
    ) {
        // Background blur effect (simulated with gradient)
        val blurGradient = Brush.radialGradient(
            colors = listOf(
                material.baseColor.copy(alpha = material.transparency * 0.8f),
                material.baseColor.copy(alpha = material.transparency * 0.4f),
                material.baseColor.copy(alpha = material.transparency * 0.1f)
            ),
            radius = size.minDimension * 0.8f,
            center = center
        )
        
        drawPath(
            path = path,
            brush = blurGradient
        )
        
        // Liquid wave distortion effect
        if (animationState.waveAmplitude > 0) {
            drawLiquidWaves(
                path = path,
                animationState = animationState,
                material = material
            )
        }
        
        // Glass reflection highlights
        if (material.enableReflections) {
            drawGlassReflections(
                path = path,
                material = material,
                animationState = animationState
            )
        }
        
        // Noise texture for authentic glass appearance
        if (material.enableNoise) {
            drawGlassNoise(
                path = path,
                intensity = GLASS_NOISE_INTENSITY
            )
        }
        
        // Border with gradient
        val borderGradient = Brush.linearGradient(
            colors = listOf(
                material.baseColor.copy(alpha = 0.6f),
                material.baseColor.copy(alpha = 0.2f),
                material.baseColor.copy(alpha = 0.4f)
            ),
            start = Offset(0f, 0f),
            end = Offset(size.width, size.height)
        )
        
        drawPath(
            path = path,
            brush = borderGradient,
            style = Stroke(
                width = with(density) { material.borderWidth.toPx() },
                cap = StrokeCap.Round,
                join = StrokeJoin.Round
            )
        )
        
        // Ambient shadow
        drawIntoCanvas { canvas ->
            val paint = Paint().apply {
                color = Color.Black
                alpha = 0.1f
                isAntiAlias = true
            }
            
            canvas.nativeCanvas.drawPath(
                path.asAndroidPath(),
                paint.asFrameworkPaint().apply {
                    setShadowLayer(
                        with(density) { material.shadowElevation.toPx() },
                        0f,
                        with(density) { (material.shadowElevation * 0.5f).toPx() },
                        Color.Black.copy(alpha = 0.2f).toArgb()
                    )
                }
            )
        }
    }
    
    /**
     * Liquid wave animation with sine-based distortion
     */
    private fun DrawScope.drawLiquidWaves(
        path: Path,
        animationState: LiquidAnimationState,
        material: GlassMaterial
    ) {
        val waveGradient = Brush.linearGradient(
            colors = listOf(
                material.baseColor.copy(alpha = animationState.waveAmplitude * 0.3f),
                Color.Transparent,
                material.baseColor.copy(alpha = animationState.waveAmplitude * 0.2f)
            ),
            start = Offset(0f, 0f),
            end = Offset(
                cos(animationState.flowDirection).toFloat() * size.width,
                sin(animationState.flowDirection).toFloat() * size.height
            )
        )
        
        // Create wave distortion using sine function
        val wavePath = Path().apply {
            val segments = 50
            val segmentWidth = size.width / segments
            
            moveTo(0f, size.height * 0.5f)
            
            for (i in 0..segments) {
                val x = i * segmentWidth
                val normalizedX = x / size.width
                val waveY = size.height * 0.5f + (
                    sin(
                        (normalizedX * animationState.waveFrequency + animationState.timeOffset * 0.001f) *
                            2 * kotlin.math.PI
                    ).toFloat() * animationState.waveAmplitude * size.height * 0.1f
                )
                
                lineTo(x.toFloat(), waveY.toFloat())
            }
            
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        
        // Intersect with main path to stay within bounds
        val clippedPath = Path.combine(PathOperation.Intersect, path, wavePath)
        
        drawPath(
            path = clippedPath,
            brush = waveGradient
        )
    }
    
    /**
     * Glass reflection highlights with dynamic positioning
     */
    private fun DrawScope.drawGlassReflections(
        path: Path,
        material: GlassMaterial,
        animationState: LiquidAnimationState
    ) {
        val reflectionGradient = Brush.linearGradient(
            colors = listOf(
                Color.White.copy(alpha = material.reflectionIntensity),
                Color.White.copy(alpha = material.reflectionIntensity * 0.5f),
                Color.Transparent
            ),
            start = Offset(0f, 0f),
            end = Offset(size.width * 0.6f, size.height * 0.6f)
        )
        
        // Dynamic reflection position based on animation state
        val reflectionOffset = Offset(
            size.width * 0.1f + cos(animationState.timeOffset * 0.0005f).toFloat() * size.width * 0.05f,
            size.height * 0.1f + sin(animationState.timeOffset * 0.0005f).toFloat() * size.height * 0.05f
        )
        
        val reflectionPath = Path().apply {
            addOval(
                androidx.compose.ui.geometry.Rect(
                    offset = reflectionOffset,
                    size = Size(size.width * 0.4f, size.height * 0.3f)
                )
            )
        }
        
        val clippedReflection = Path.combine(PathOperation.Intersect, path, reflectionPath)
        
        drawPath(
            path = clippedReflection,
            brush = reflectionGradient
        )
    }
    
    /**
     * Subtle noise texture for authentic glass appearance
     */
    private fun DrawScope.drawGlassNoise(
        path: Path,
        intensity: Float
    ) {
        // Simplified noise implementation using dithering pattern
        val noiseSize = 4f
        val cols = (size.width / noiseSize).toInt()
        val rows = (size.height / noiseSize).toInt()
        
        for (col in 0 until cols) {
            for (row in 0 until rows) {
                val x = col * noiseSize
                val y = row * noiseSize
                
                // Pseudo-random noise based on position
                val noise = ((col * 73 + row * 37) % 255) / 255f
                val alpha = intensity * noise * 0.5f
                
                if (alpha > 0.01f) {
                    drawRect(
                        color = Color.White.copy(alpha = alpha),
                        topLeft = Offset(x, y),
                        size = Size(noiseSize, noiseSize)
                    )
                }
            }
        }
    }
}
