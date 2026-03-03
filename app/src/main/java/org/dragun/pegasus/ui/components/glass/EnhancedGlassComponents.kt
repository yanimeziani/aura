package org.dragun.pegasus.ui.components.glass

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.dragun.pegasus.ui.rendering.LiquidGlassRenderEngine
import org.dragun.pegasus.ui.theme.LiquidGlassTheme

/**
 * Enhanced glass components with iOS 16 design patterns and optimized rendering
 * Uses the LiquidGlassRenderEngine for high-performance visual effects
 */

/**
 * iOS 16-style glass card with advanced liquid effects and haptic feedback
 */
@Composable
fun EnhancedGlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 20.dp,
    elevation: Dp = 8.dp,
    enableLiquidEffect: Boolean = true,
    enableHapticFeedback: Boolean = true,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val renderEngine = remember { LiquidGlassRenderEngine() }
    val hapticFeedback = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    
    // Enhanced material properties for iOS 16 look
    val glassMaterial = remember {
        LiquidGlassRenderEngine.GlassMaterial(
            baseColor = Color.White,
            transparency = 0.15f,
            blurStrength = 0.9f,
            reflectionIntensity = 0.2f,
            cornerRadius = cornerRadius,
            shadowElevation = elevation,
            enableReflections = true,
            enableNoise = true
        )
    }
    
    // Liquid animation state
    var animationState by remember {
        mutableStateOf(
            LiquidGlassRenderEngine.LiquidAnimationState(
                waveAmplitude = if (enableLiquidEffect) 0.3f else 0f,
                waveFrequency = 2.0f,
                flowDirection = 0.5f
            )
        )
    }
    
    // Update animation over time
    LaunchedEffect(enableLiquidEffect) {
        if (enableLiquidEffect) {
            while (true) {
                animationState = animationState.copy(
                    timeOffset = animationState.timeOffset + 16f // ~60fps
                )
                kotlinx.coroutines.delay(16)
            }
        }
    }
    
    // Haptic feedback on press
    LaunchedEffect(isPressed) {
        if (isPressed && enableHapticFeedback && onClick != null) {
            hapticFeedback.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
        }
    }
    
    renderEngine.renderLiquidGlass(
        modifier = modifier
            .then(
                if (onClick != null) {
                    Modifier.clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = onClick
                    )
                } else Modifier
            ),
        material = glassMaterial,
        animationState = animationState,
        isPressed = isPressed
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            content = content
        )
    }
}

/**
 * iOS 16-style glass button with enhanced visual effects
 */
@Composable
fun EnhancedGlassButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    variant: GlassButtonVariant = GlassButtonVariant.Primary,
    size: GlassButtonSize = GlassButtonSize.Medium,
    icon: ImageVector? = null,
    enableHapticFeedback: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    val renderEngine = remember { LiquidGlassRenderEngine() }
    val hapticFeedback = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    
    val buttonColors = when (variant) {
        GlassButtonVariant.Primary -> MaterialTheme.colorScheme.primary
        GlassButtonVariant.Secondary -> MaterialTheme.colorScheme.secondary
        GlassButtonVariant.Tertiary -> MaterialTheme.colorScheme.tertiary
        GlassButtonVariant.Destructive -> MaterialTheme.colorScheme.error
    }
    
    val buttonPadding = when (size) {
        GlassButtonSize.Small -> PaddingValues(horizontal = 16.dp, vertical = 8.dp)
        GlassButtonSize.Medium -> PaddingValues(horizontal = 20.dp, vertical = 14.dp)
        GlassButtonSize.Large -> PaddingValues(horizontal = 24.dp, vertical = 18.dp)
    }
    
    val cornerRadius = when (size) {
        GlassButtonSize.Small -> 12.dp
        GlassButtonSize.Medium -> 16.dp
        GlassButtonSize.Large -> 20.dp
    }
    
    val glassMaterial = remember(variant) {
        LiquidGlassRenderEngine.GlassMaterial(
            baseColor = buttonColors,
            transparency = 0.9f,
            blurStrength = 0.7f,
            cornerRadius = cornerRadius,
            shadowElevation = 6.dp,
            enableReflections = true,
            enableNoise = false
        )
    }
    
    LaunchedEffect(isPressed) {
        if (isPressed && enableHapticFeedback && enabled) {
            hapticFeedback.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
        }
    }
    
    renderEngine.renderLiquidGlass(
        modifier = modifier
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                onClick = onClick
            ),
        material = glassMaterial,
        isPressed = isPressed && enabled
    ) {
        Row(
            modifier = Modifier.padding(buttonPadding),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon?.let {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onPrimary
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            content()
        }
    }
}

/**
 * iOS 16-style glass text field with enhanced focus effects
 */
@Composable
fun EnhancedGlassTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    leadingIcon: ImageVector? = null,
    trailingIcon: ImageVector? = null,
    isError: Boolean = false,
    enabled: Boolean = true,
    singleLine: Boolean = true,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    keyboardOptions: KeyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    val renderEngine = remember { LiquidGlassRenderEngine() }
    val focusRequester = remember { FocusRequester() }
    var isFocused by remember { mutableStateOf(false) }
    
    val glassMaterial = remember(isFocused, isError) {
        LiquidGlassRenderEngine.GlassMaterial(
            baseColor = when {
                isError -> MaterialTheme.colorScheme.error
                isFocused -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.surfaceVariant
            },
            transparency = if (isFocused) 0.2f else 0.1f,
            blurStrength = 0.6f,
            cornerRadius = 16.dp,
            shadowElevation = if (isFocused) 4.dp else 2.dp,
            borderWidth = if (isFocused || isError) 2.dp else 1.dp,
            enableReflections = isFocused,
            enableNoise = false
        )
    }
    
    renderEngine.renderLiquidGlass(
        modifier = modifier,
        material = glassMaterial
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            leadingIcon?.let {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = if (isFocused) MaterialTheme.colorScheme.primary
                           else MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(12.dp))
            }
            
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier
                    .weight(1f)
                    .focusRequester(focusRequester)
                    .onFocusChanged { isFocused = it.isFocused },
                enabled = enabled,
                singleLine = singleLine,
                visualTransformation = visualTransformation,
                keyboardOptions = keyboardOptions,
                keyboardActions = keyboardActions,
                textStyle = TextStyle(
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Normal
                ),
                decorationBox = { innerTextField ->
                    if (value.isEmpty() && placeholder.isNotEmpty()) {
                        Text(
                            text = placeholder,
                            style = TextStyle(
                                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                                fontSize = 16.sp
                            )
                        )
                    }
                    innerTextField()
                }
            )
            
            trailingIcon?.let {
                Spacer(modifier = Modifier.width(12.dp))
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * iOS 16-style glass navigation bar
 */
@Composable
fun EnhancedGlassTopBar(
    title: String,
    modifier: Modifier = Modifier,
    navigationIcon: ImageVector? = null,
    onNavigationClick: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
    enableBlur: Boolean = true,
) {
    val renderEngine = remember { LiquidGlassRenderEngine() }
    
    val glassMaterial = remember {
        LiquidGlassRenderEngine.GlassMaterial(
            baseColor = MaterialTheme.colorScheme.surface,
            transparency = 0.8f,
            blurStrength = if (enableBlur) 1.0f else 0.0f,
            cornerRadius = 0.dp,
            shadowElevation = 1.dp,
            borderWidth = 0.dp,
            enableReflections = false,
            enableNoise = false
        )
    }
    
    renderEngine.renderLiquidGlass(
        modifier = modifier.fillMaxWidth(),
        material = glassMaterial
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .statusBarsPadding(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            navigationIcon?.let { icon ->
                IconButton(
                    onClick = { onNavigationClick?.invoke() },
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = "Navigation",
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                }
                Spacer(Modifier.width(8.dp))
            }
            
            Text(
                text = title,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.headlineSmall.copy(
                    fontWeight = FontWeight.SemiBold
                ),
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1
            )
            
            Row {
                actions()
            }
        }
    }
}

/**
 * iOS 16-style glass floating action button
 */
@Composable
fun EnhancedGlassFAB(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector = Icons.Default.Add,
    containerColor: Color = MaterialTheme.colorScheme.primary,
    enableHapticFeedback: Boolean = true,
) {
    val renderEngine = remember { LiquidGlassRenderEngine() }
    val hapticFeedback = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    
    val glassMaterial = remember(containerColor) {
        LiquidGlassRenderEngine.GlassMaterial(
            baseColor = containerColor,
            transparency = 0.9f,
            blurStrength = 0.8f,
            cornerRadius = 28.dp,
            shadowElevation = 12.dp,
            enableReflections = true,
            enableNoise = false
        )
    }
    
    LaunchedEffect(isPressed) {
        if (isPressed && enableHapticFeedback) {
            hapticFeedback.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.LongPress)
        }
    }
    
    renderEngine.renderLiquidGlass(
        modifier = modifier
            .size(56.dp)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            ),
        material = glassMaterial,
        isPressed = isPressed
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = "Action",
                modifier = Modifier.size(24.dp),
                tint = MaterialTheme.colorScheme.onPrimary
            )
        }
    }
}

// Supporting enums and data classes
enum class GlassButtonVariant {
    Primary, Secondary, Tertiary, Destructive
}

enum class GlassButtonSize {
    Small, Medium, Large
}