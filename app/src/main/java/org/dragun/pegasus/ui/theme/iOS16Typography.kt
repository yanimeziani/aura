package org.dragun.pegasus.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import org.dragun.pegasus.R

/**
 * iOS 16 Typography System for Android
 * Implements San Francisco (SF) Pro Display and SF Pro Text equivalents
 */

// SF Pro Display equivalent - using system fonts that closely match SF Pro
private val SFProDisplay = FontFamily(
    Font(R.font.sf_pro_display_regular, FontWeight.Normal),
    Font(R.font.sf_pro_display_medium, FontWeight.Medium),
    Font(R.font.sf_pro_display_semibold, FontWeight.SemiBold),
    Font(R.font.sf_pro_display_bold, FontWeight.Bold),
    Font(R.font.sf_pro_display_heavy, FontWeight.Black)
)

private val SFProText = FontFamily(
    Font(R.font.sf_pro_text_regular, FontWeight.Normal),
    Font(R.font.sf_pro_text_medium, FontWeight.Medium),
    Font(R.font.sf_pro_text_semibold, FontWeight.SemiBold),
    Font(R.font.sf_pro_text_bold, FontWeight.Bold)
)

// Fallback to system fonts if SF Pro fonts are not available
private val SystemDisplay = FontFamily.Default
private val SystemText = FontFamily.Default

/**
 * iOS 16 Typography Scale
 * Based on Apple's Human Interface Guidelines
 */
val iOS16Typography = Typography(
    // Large Title - iOS 16 style
    displayLarge = TextStyle(
        fontFamily = SFProDisplay,
        fontWeight = FontWeight.Bold,
        fontSize = 34.sp,
        lineHeight = 41.sp,
        letterSpacing = (-0.5).sp
    ),
    
    // Title 1 - iOS 16 style
    displayMedium = TextStyle(
        fontFamily = SFProDisplay,
        fontWeight = FontWeight.Bold,
        fontSize = 28.sp,
        lineHeight = 34.sp,
        letterSpacing = (-0.3).sp
    ),
    
    // Title 2 - iOS 16 style
    displaySmall = TextStyle(
        fontFamily = SFProDisplay,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = (-0.2).sp
    ),
    
    // Title 3 - iOS 16 style
    headlineLarge = TextStyle(
        fontFamily = SFProDisplay,
        fontWeight = FontWeight.SemiBold,
        fontSize = 20.sp,
        lineHeight = 25.sp,
        letterSpacing = (-0.1).sp
    ),
    
    // Headline - iOS 16 style
    headlineMedium = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = (-0.05).sp
    ),
    
    // Body - iOS 16 style
    headlineSmall = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    ),
    
    // Callout - iOS 16 style
    titleLarge = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 21.sp,
        letterSpacing = 0.sp
    ),
    
    // Subhead - iOS 16 style
    titleMedium = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp
    ),
    
    // Footnote - iOS 16 style
    titleSmall = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        letterSpacing = 0.sp
    ),
    
    // Body Large - iOS 16 style
    bodyLarge = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    ),
    
    // Body Medium - iOS 16 style
    bodyMedium = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp
    ),
    
    // Body Small - iOS 16 style (Caption 1)
    bodySmall = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.sp
    ),
    
    // Label Large - iOS 16 style
    labelLarge = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp
    ),
    
    // Label Medium - iOS 16 style
    labelMedium = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        letterSpacing = 0.sp
    ),
    
    // Label Small - iOS 16 style (Caption 2)
    labelSmall = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 11.sp,
        lineHeight = 13.sp,
        letterSpacing = 0.sp
    )
)

/**
 * iOS 16 Typography Extensions
 * Additional text styles that match iOS 16 specifications
 */
object iOS16TextStyles {
    
    // Navigation Title (Large)
    val navigationTitleLarge = TextStyle(
        fontFamily = SFProDisplay,
        fontWeight = FontWeight.Bold,
        fontSize = 34.sp,
        lineHeight = 41.sp,
        letterSpacing = (-0.5).sp
    )
    
    // Navigation Title (Small)
    val navigationTitleSmall = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = (-0.05).sp
    )
    
    // Button Text
    val buttonText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // Tab Bar Text
    val tabBarText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Medium,
        fontSize = 10.sp,
        lineHeight = 12.sp,
        letterSpacing = 0.sp
    )
    
    // Alert Title
    val alertTitle = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = (-0.05).sp
    )
    
    // Alert Message
    val alertMessage = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 13.sp,
        lineHeight = 18.sp,
        letterSpacing = 0.sp
    )
    
    // Input Field Text
    val inputFieldText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // Input Field Placeholder
    val inputFieldPlaceholder = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // List Item Title
    val listItemTitle = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // List Item Subtitle
    val listItemSubtitle = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp
    )
    
    // List Item Detail
    val listItemDetail = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // Status Text
    val statusText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Medium,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.sp
    )
    
    // Badge Text
    val badgeText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.SemiBold,
        fontSize = 12.sp,
        lineHeight = 16.sp,
        letterSpacing = 0.sp
    )
    
    // Menu Item Text
    val menuItemText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // Picker Text
    val pickerText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 23.sp,
        lineHeight = 29.sp,
        letterSpacing = 0.sp
    )
    
    // Search Field Text
    val searchFieldText = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
    
    // Search Field Placeholder
    val searchFieldPlaceholder = TextStyle(
        fontFamily = SFProText,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        letterSpacing = 0.sp
    )
}

/**
 * iOS 16 Dynamic Type Support
 * Accessibility text scaling that matches iOS behavior
 */
object iOS16DynamicType {
    
    sealed class TextSize(val scale: Float) {
        object ExtraSmall : TextSize(0.82f)      // xSmall
        object Small : TextSize(0.88f)            // Small
        object Medium : TextSize(1.0f)            // Default
        object Large : TextSize(1.12f)            // Large
        object ExtraLarge : TextSize(1.24f)       // xLarge
        object ExtraExtraLarge : TextSize(1.35f)  // xxLarge
        object ExtraExtraExtraLarge : TextSize(1.53f) // xxxLarge
        
        // Accessibility sizes
        object Accessibility1 : TextSize(1.76f)   // AX1
        object Accessibility2 : TextSize(2.05f)   // AX2
        object Accessibility3 : TextSize(2.35f)   // AX3
        object Accessibility4 : TextSize(2.76f)   // AX4
        object Accessibility5 : TextSize(3.12f)   // AX5
    }
    
    fun scaleTextStyle(textStyle: TextStyle, textSize: TextSize): TextStyle {
        return textStyle.copy(
            fontSize = textStyle.fontSize * textSize.scale,
            lineHeight = textStyle.lineHeight * textSize.scale
        )
    }
}