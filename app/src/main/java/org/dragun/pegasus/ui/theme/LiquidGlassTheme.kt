package org.dragun.pegasus.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val iOS26DarkPrimary = Color(0xFF0A84FF)
private val iOS26DarkSecondary = Color(0xFF5E5CE6)
private val iOS26DarkTertiary = Color(0xFFFF9F0A)
private val iOS26DarkBackground = Color(0xFF000000)
private val iOS26DarkSurface = Color(0xFF1C1C1E)
private val iOS26DarkSurfaceGlass = Color(0x331C1C1E)
private val iOS26DarkOnSurface = Color(0xFFFFFFFF)
private val iOS26DarkOnSurfaceVariant = Color(0xFF8E8E93)

private val iOS26LightPrimary = Color(0xFF007AFF)
private val iOS26LightSecondary = Color(0xFF5E5CE6)
private val iOS26LightTertiary = Color(0xFFFF9500)
private val iOS26LightBackground = Color(0xFFF2F2F7)
private val iOS26LightSurface = Color(0xFFFFFFFF)
private val iOS26LightSurfaceGlass = Color(0x33FFFFFF)
private val iOS26LightOnSurface = Color(0xFF000000)
private val iOS26LightOnSurfaceVariant = Color(0xFF3C3C43)

private val LiquidGlassDark = Brush.verticalGradient(
    colors = listOf(
        Color(0x1AFFFFFF),
        Color(0x0DFFFFFF),
        Color(0x05262626),
    )
)

private val LiquidGlassLight = Brush.verticalGradient(
    colors = listOf(
        Color(0x1A000000),
        Color(0x05000000),
    )
)

private val LiquidGlassBorderDark = Color(0x33FFFFFF)
private val LiquidGlassBorderLight = Color(0x1A000000)

private val iOS26DarkColors = darkColorScheme(
    primary = iOS26DarkPrimary,
    onPrimary = Color.White,
    primaryContainer = Color(0xFF1A3A5C),
    secondary = iOS26DarkSecondary,
    onSecondary = Color.White,
    tertiary = iOS26DarkTertiary,
    background = iOS26DarkBackground,
    onBackground = iOS26DarkOnSurface,
    surface = iOS26DarkSurface,
    onSurface = iOS26DarkOnSurface,
    surfaceVariant = Color(0xFF2C2C2E),
    onSurfaceVariant = iOS26DarkOnSurfaceVariant,
    outline = Color(0x38383A),
    error = Color(0xFFFF453A),
    onError = Color.White,
)

private val iOS26LightColors = lightColorScheme(
    primary = iOS26LightPrimary,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD1E4FF),
    secondary = iOS26LightSecondary,
    onSecondary = Color.White,
    tertiary = iOS26LightTertiary,
    background = iOS26LightBackground,
    onBackground = iOS26LightOnSurface,
    surface = iOS26LightSurface,
    onSurface = iOS26LightOnSurface,
    surfaceVariant = Color(0xFFE5E5EA),
    onSurfaceVariant = iOS26LightOnSurfaceVariant,
    outline = Color(0x29000000),
    error = Color(0xFFFF3B30),
    onError = Color.White,
)

data class LiquidGlassColors(
    val glassSurface: Color,
    val glassBorder: Color,
    val glassHighlight: Color,
    val glassShadow: Color,
    val liquidGradient: Brush,
)

private val darkGlassColors = LiquidGlassColors(
    glassSurface = Color(0x1AFFFFFF),
    glassBorder = Color(0x33FFFFFF),
    glassHighlight = Color(0x4DFFFFFF),
    glassShadow = Color(0x40000000),
    liquidGradient = LiquidGlassDark,
)

private val lightGlassColors = LiquidGlassColors(
    glassSurface = Color(0x1A000000),
    glassBorder = Color(0x1A000000),
    glassHighlight = Color(0x26000000),
    glassShadow = Color(0x0D000000),
    liquidGradient = LiquidGlassLight,
)

object LiquidGlassTheme {
    val glassColors: LiquidGlassColors
        @Composable
        get() = if (isSystemInDarkTheme()) darkGlassColors else lightGlassColors
}

@Composable
fun LiquidGlassTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colorScheme = if (darkTheme) iOS26DarkColors else iOS26LightColors
    
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            window.navigationBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = !darkTheme
                isAppearanceLightNavigationBars = !darkTheme
            }
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = iOS16Typography,
        content = content,
    )
}
