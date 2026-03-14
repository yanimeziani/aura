package org.dragun.pegasus.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val BrutalistDarkScheme = darkColorScheme(
    primary = Color(0xFF00FF00), // Pure Green
    onPrimary = Color.Black,
    secondary = Color(0xFFFFFF00), // Pure Yellow
    onSecondary = Color.Black,
    tertiary = Color(0xFFFF00FF), // Magenta
    background = Color.Black,
    onBackground = Color.White,
    surface = Color(0xFF121212),
    onSurface = Color.White,
    error = Color(0xFFFF0000), // Pure Red
    outline = Color.White,
)

private val BrutalistLightScheme = lightColorScheme(
    primary = Color.Black,
    onPrimary = Color(0xFF00FF00),
    secondary = Color.White,
    onSecondary = Color.Black,
    background = Color.White,
    onBackground = Color.Black,
    surface = Color.White,
    onSurface = Color.Black,
    error = Color(0xFFFF0000),
    outline = Color.Black,
)

val BrutalistTypography = Typography(
    titleLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Black,
        fontSize = 24.sp,
        letterSpacing = (-1).sp
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 14.sp
    )
)

@Composable
fun BrutalistTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) BrutalistDarkScheme else BrutalistLightScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = BrutalistTypography,
        content = content
    )
}
