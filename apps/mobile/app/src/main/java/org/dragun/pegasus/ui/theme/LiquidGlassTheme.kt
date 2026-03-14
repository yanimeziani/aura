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

private val PegasusDarkScheme = darkColorScheme(
    primary = Color(0xFF79C5FF),
    onPrimary = Color(0xFF00344F),
    primaryContainer = Color(0xFF004C72),
    onPrimaryContainer = Color(0xFFCBE8FF),
    secondary = Color(0xFF86D2C6),
    onSecondary = Color(0xFF003730),
    secondaryContainer = Color(0xFF1D4E46),
    onSecondaryContainer = Color(0xFFA2F2E4),
    tertiary = Color(0xFFE2C470),
    onTertiary = Color(0xFF3C2F00),
    background = Color(0xFF0D141A),
    onBackground = Color(0xFFE2EAF1),
    surface = Color(0xFF111B23),
    onSurface = Color(0xFFE2EAF1),
    surfaceVariant = Color(0xFF26343F),
    onSurfaceVariant = Color(0xFFB6C8D6),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
)

private val PegasusLightScheme = lightColorScheme(
    primary = Color(0xFF005D8A),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFC6E7FF),
    onPrimaryContainer = Color(0xFF001D2D),
    secondary = Color(0xFF14635A),
    onSecondary = Color.White,
    secondaryContainer = Color(0xFF9FF2E5),
    onSecondaryContainer = Color(0xFF00201C),
    tertiary = Color(0xFF6B580E),
    onTertiary = Color.White,
    background = Color(0xFFF4F8FC),
    onBackground = Color(0xFF101418),
    surface = Color(0xFFF9FBFF),
    onSurface = Color(0xFF101418),
    surfaceVariant = Color(0xFFDCE7F2),
    onSurfaceVariant = Color(0xFF3F4D59),
    error = Color(0xFFBA1A1A),
    onError = Color.White,
)

private val motionGradientDark = Brush.verticalGradient(
    colors = listOf(
        Color(0xFF0D141A),
        Color(0xFF101B23),
        Color(0xFF132430),
    )
)

private val motionGradientLight = Brush.verticalGradient(
    colors = listOf(
        Color(0xFFF6FAFF),
        Color(0xFFF1F8FF),
        Color(0xFFE7F3FF),
    )
)

data class MotionSurfaceTokens(
    val cardStart: Color,
    val cardEnd: Color,
    val outline: Color,
    val glow: Color,
    val background: Brush,
)

private val darkTokens = MotionSurfaceTokens(
    cardStart = Color(0x40263A4A),
    cardEnd = Color(0x33223844),
    outline = Color(0x66A9C5D9),
    glow = Color(0x663A607A),
    background = motionGradientDark,
)

private val lightTokens = MotionSurfaceTokens(
    cardStart = Color(0xCCFFFFFF),
    cardEnd = Color(0xB8F3F8FF),
    outline = Color(0x806D8598),
    glow = Color(0x6680A9C5),
    background = motionGradientLight,
)

object LiquidGlassPalette {
    val surfaceTokens: MotionSurfaceTokens
        @Composable
        get() = if (isSystemInDarkTheme()) darkTokens else lightTokens
}

@Composable
fun LiquidGlassTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val view = LocalView.current
            if (darkTheme) dynamicDarkColorScheme(view.context) else dynamicLightColorScheme(view.context)
        }
        darkTheme -> PegasusDarkScheme
        else -> PegasusLightScheme
    }

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
        typography = Typography(),
        content = content,
    )
}

@Composable
fun PegasusMaterialTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    LiquidGlassTheme(darkTheme = darkTheme, dynamicColor = dynamicColor, content = content)
}
