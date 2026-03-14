package org.dragun.pegasus.ui.components.adaptive

import androidx.compose.foundation.layout.*
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.window.layout.FoldingFeature

/**
 * A wrapper that adapts its content for foldable devices (Fold, Flip).
 * Supports Flex Mode (half-opened) and different screen sizes.
 */
@Composable
fun FoldableLayout(
    content: @Composable (isFolded: Boolean, isLandscape: Boolean) -> Unit
) {
    val adaptiveInfo = currentWindowAdaptiveInfo()
    val windowSize = adaptiveInfo.windowSizeClass
    val posturingInfo = adaptiveInfo.windowPosture
    
    // Determine if we are in Flex Mode (half-opened)
    val isTabletop = posturingInfo.isTabletop
    val isLandscape = windowSize.windowWidthSizeClass.toString().contains("Expanded") || 
                     windowSize.windowHeightSizeClass.toString().contains("Compact")

    Box(modifier = Modifier.fillMaxSize()) {
        content(isTabletop, isLandscape)
    }
}

/**
 * Optimization for Z Flip (Small screen reachability)
 */
@Composable
fun ReachabilityColumn(
    modifier: Modifier = Modifier,
    verticalArrangement: Arrangement.Vertical = Arrangement.Top,
    content: @Composable ColumnScope.() -> Unit
) {
    val adaptiveInfo = currentWindowAdaptiveInfo()
    val isSmallScreen = adaptiveInfo.windowSizeClass.windowWidthSizeClass.toString().contains("Compact")

    Column(
        modifier = modifier
            .fillMaxSize()
            .then(
                if (isSmallScreen) Modifier.padding(top = 120.dp) // Push content down for thumb reachability
                else Modifier
            ),
        verticalArrangement = verticalArrangement,
        content = content
    )
}
