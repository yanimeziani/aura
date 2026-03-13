package co.anomaly.pegasus.security

import android.content.Context
import android.content.Intent
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Emergency Kill Switch Button
 * 
 * UX Design:
 * - Hold for 3 seconds to activate
 * - Visual countdown ring
 * - Haptic feedback
 * - No confirmation dialog (speed > safety in emergency)
 * 
 * "L'interdiction de toute panique" — le bouton est calme, délibéré
 */

private val EmergencyRed = Color(0xFFBF616A)
private val EmergencyRedDark = Color(0xFF8B3D44)

@Composable
fun EmergencyButton(
    modifier: Modifier = Modifier,
    onTriggered: () -> Unit
) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    
    var isHolding by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var triggered by remember { mutableStateOf(false) }
    
    val holdDurationMs = 3000L
    
    LaunchedEffect(isHolding) {
        if (isHolding && !triggered) {
            val startTime = System.currentTimeMillis()
            
            while (isHolding && progress < 1f) {
                val elapsed = System.currentTimeMillis() - startTime
                progress = (elapsed.toFloat() / holdDurationMs).coerceIn(0f, 1f)
                
                // Haptic ticks as progress increases
                if ((progress * 10).toInt() > ((progress - 0.01f) * 10).toInt()) {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
                
                delay(16) // ~60fps
            }
            
            if (progress >= 1f) {
                triggered = true
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                vibrateEmergency(context)
                onTriggered()
            }
        } else {
            // Reset if released early
            progress = 0f
        }
    }
    
    Box(
        modifier = modifier
            .size(120.dp)
            .clip(CircleShape)
            .background(if (triggered) EmergencyRedDark else EmergencyRed.copy(alpha = 0.2f))
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = {
                        isHolding = true
                        tryAwaitRelease()
                        isHolding = false
                    }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        // Progress ring
        if (isHolding && !triggered) {
            CircularProgressIndicator(
                progress = { progress },
                modifier = Modifier.size(110.dp),
                color = EmergencyRed,
                strokeWidth = 4.dp,
                trackColor = EmergencyRed.copy(alpha = 0.3f)
            )
        }
        
        // Center content
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                Icons.Default.Warning,
                contentDescription = null,
                tint = if (triggered) Color.White else EmergencyRed,
                modifier = Modifier.size(32.dp)
            )
            
            Spacer(Modifier.height(4.dp))
            
            Text(
                if (triggered) "PURGING" else if (isHolding) "HOLD" else "EMERGENCY",
                color = if (triggered) Color.White else EmergencyRed,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

/**
 * Emergency vibration pattern
 * Three long pulses
 */
private fun vibrateEmergency(context: Context) {
    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    vibrator?.vibrate(
        VibrationEffect.createWaveform(
            longArrayOf(0, 200, 100, 200, 100, 200),
            -1
        )
    )
}

/**
 * Panic-free emergency screen
 * 
 * Design philosophy:
 * - Calm, deliberate interface
 * - Clear but not alarming
 * - No flashing, no sirens
 * - "L'architecture est bâtie pour brûler" — accept it
 */
@Composable
fun EmergencyScreen(
    onEmergencyTriggered: () -> Unit
) {
    var showConfirmation by remember { mutableStateOf(false) }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF2E3440)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(32.dp)
        ) {
            if (!showConfirmation) {
                Text(
                    "System Secure",
                    color = Color(0xFF88C0D0),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Light
                )
                
                Text(
                    "Hold to purge",
                    color = Color(0xFF4C566A),
                    fontSize = 14.sp
                )
            }
            
            EmergencyButton(
                onTriggered = {
                    showConfirmation = true
                    onEmergencyTriggered()
                }
            )
            
            if (showConfirmation) {
                Text(
                    "All keys rotated",
                    color = Color(0xFFA3BE8C),
                    fontSize = 16.sp
                )
                Text(
                    "Memory purged",
                    color = Color(0xFFA3BE8C),
                    fontSize = 16.sp
                )
                Text(
                    "Node disconnected",
                    color = Color(0xFFA3BE8C),
                    fontSize = 16.sp
                )
            }
        }
    }
}
