package org.dragun.pegasus.ui.screens

import androidx.biometric.BiometricPrompt
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import org.dragun.pegasus.ui.components.glass.*

@Composable
fun LoginScreen(viewModel: LoginViewModel, onLoginSuccess: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val activity = context as FragmentActivity

    // Keep callback reference fresh for BiometricPrompt closures
    val currentOnLoginSuccess by rememberUpdatedState(onLoginSuccess)

    // ── BiometricPrompt for unlock (returning user) ─────────────────
    val unlockCallback = remember {
        object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                result.cryptoObject?.cipher?.let { cipher ->
                    viewModel.completeBiometricLogin(cipher) { currentOnLoginSuccess() }
                }
            }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                if (errorCode != BiometricPrompt.ERROR_NEGATIVE_BUTTON &&
                    errorCode != BiometricPrompt.ERROR_USER_CANCELED
                ) {
                    viewModel.onBiometricError(errString.toString())
                }
                viewModel.showPasswordForm()
            }
        }
    }
    val unlockPrompt = remember(activity) {
        BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), unlockCallback)
    }
    val unlockPromptInfo = remember {
        BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock Pegasus")
            .setSubtitle("Authenticate to access mission control")
            .setNegativeButtonText("Use password")
            .build()
    }

    // ── BiometricPrompt for enrollment (after first password login) ──
    val enrollCallback = remember {
        object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                result.cryptoObject?.cipher?.let { cipher ->
                    viewModel.enrollBiometric(cipher)
                }
            }
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                viewModel.skipBiometricEnrollment()
            }
        }
    }
    val enrollPrompt = remember(activity) {
        BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), enrollCallback)
    }
    val enrollPromptInfo = remember {
        BiometricPrompt.PromptInfo.Builder()
            .setTitle("Enable Biometric Unlock")
            .setSubtitle("Secure future logins with your fingerprint")
            .setNegativeButtonText("Cancel")
            .build()
    }

    // ── Auto-trigger biometric on screen load ───────────────────────
    LaunchedEffect(state.biometricEnrolled) {
        if (state.biometricEnrolled && !state.showPasswordForm) {
            val cipher = viewModel.getDecryptCipher()
            if (cipher != null) {
                unlockPrompt.authenticate(unlockPromptInfo, BiometricPrompt.CryptoObject(cipher))
            }
        }
    }

    // ── Handle enrollment dialog trigger ────────────────────────────
    LaunchedEffect(state.showBiometricEnrollment) {
        if (state.showBiometricEnrollment) {
            val cipher = viewModel.getEncryptCipher()
            if (cipher != null) {
                enrollPrompt.authenticate(enrollPromptInfo, BiometricPrompt.CryptoObject(cipher))
            } else {
                viewModel.skipBiometricEnrollment()
            }
        }
    }

    // ── UI ───────────────────────────────────────────────────────────
    val showBiometricFirst = state.biometricEnrolled && !state.showPasswordForm

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.background,
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.05f),
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(32.dp)
                .statusBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Spacer(Modifier.height(48.dp))

            AnimatedContent(
                targetState = showBiometricFirst,
                transitionSpec = {
                    fadeIn() + slideInVertically { it / 4 } togetherWith
                        fadeOut() + slideOutVertically { -it / 4 }
                },
                label = "login-mode",
            ) { biometricMode ->
                if (biometricMode) {
                    BiometricFirstContent(
                        error = state.error,
                        onTapFingerprint = {
                            val cipher = viewModel.getDecryptCipher()
                            if (cipher != null) {
                                unlockPrompt.authenticate(
                                    unlockPromptInfo,
                                    BiometricPrompt.CryptoObject(cipher),
                                )
                            }
                        },
                        onUsePassword = { viewModel.showPasswordForm() },
                    )
                } else {
                    PasswordFormContent(
                        state = state,
                        viewModel = viewModel,
                        onLoginSuccess = onLoginSuccess,
                        showBiometricOption = state.biometricEnrolled,
                        onSwitchToBiometric = {
                            viewModel.run {
                                val cipher = getDecryptCipher()
                                if (cipher != null) {
                                    unlockPrompt.authenticate(
                                        unlockPromptInfo,
                                        BiometricPrompt.CryptoObject(cipher),
                                    )
                                }
                            }
                        },
                    )
                }
            }

            Spacer(Modifier.height(32.dp))

            Text(
                text = "dragun.app",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// ── Biometric-first screen (returning user) ─────────────────────────────

@Composable
private fun BiometricFirstContent(
    error: String?,
    onTapFingerprint: () -> Unit,
    onUsePassword: () -> Unit,
) {
    GlassSurface(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 28.dp,
    ) {
        Column(
            modifier = Modifier.padding(36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "PEGASUS",
                style = MaterialTheme.typography.headlineLarge.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 6.sp,
                ),
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "Mission Control",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(Modifier.height(48.dp))

            // Large fingerprint icon — tap to authenticate
            IconButton(
                onClick = onTapFingerprint,
                modifier = Modifier.size(80.dp),
            ) {
                Icon(
                    imageVector = Icons.Default.Fingerprint,
                    contentDescription = "Authenticate with fingerprint",
                    modifier = Modifier.size(64.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(Modifier.height(12.dp))

            Text(
                text = "Tap to unlock",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            AnimatedVisibility(visible = error != null) {
                error?.let {
                    Spacer(Modifier.height(16.dp))
                    Text(
                        it,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            Spacer(Modifier.height(32.dp))

            Text(
                text = "Use password",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable(onClick = onUsePassword),
            )
        }
    }
}

// ── Password form (first-time or fallback) ──────────────────────────────

@Composable
private fun PasswordFormContent(
    state: LoginUiState,
    viewModel: LoginViewModel,
    onLoginSuccess: () -> Unit,
    showBiometricOption: Boolean,
    onSwitchToBiometric: () -> Unit,
) {
    var showPassword by remember { mutableStateOf(false) }

    GlassSurface(
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = 28.dp,
    ) {
        Column(
            modifier = Modifier.padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "PEGASUS",
                style = MaterialTheme.typography.headlineLarge.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 6.sp,
                ),
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "Cerberus Control Plane",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(Modifier.height(32.dp))

            GlassTextField(
                value = state.apiUrl,
                onValueChange = viewModel::updateApiUrl,
                placeholder = "Server URL",
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(14.dp))

            GlassTextField(
                value = state.username,
                onValueChange = viewModel::updateUsername,
                placeholder = "Username",
                leadingIcon = {
                    Icon(Icons.Default.Person, null, tint = MaterialTheme.colorScheme.primary)
                },
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(14.dp))

            GlassTextField(
                value = state.password,
                onValueChange = viewModel::updatePassword,
                placeholder = "Password",
                leadingIcon = {
                    Icon(Icons.Default.Lock, null, tint = MaterialTheme.colorScheme.primary)
                },
                trailingIcon = {
                    IconButton(onClick = { showPassword = !showPassword }) {
                        Icon(
                            if (showPassword) Icons.Default.VisibilityOff
                            else Icons.Default.Visibility,
                            contentDescription = "Toggle password",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                },
                visualTransformation = if (showPassword) VisualTransformation.None
                else PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )

            AnimatedVisibility(
                visible = state.error != null,
                enter = fadeIn() + slideInVertically(initialOffsetY = { -it / 2 }),
                exit = fadeOut() + slideOutVertically(targetOffsetY = { -it / 2 }),
            ) {
                state.error?.let {
                    Spacer(Modifier.height(12.dp))
                    Text(
                        it,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Fingerprint shortcut (if enrolled, user can switch back)
                if (showBiometricOption) {
                    IconButton(onClick = onSwitchToBiometric) {
                        Icon(
                            Icons.Default.Fingerprint,
                            contentDescription = "Use fingerprint",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(28.dp),
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                }

                GlassButton(
                    onClick = { viewModel.login(onLoginSuccess) },
                    enabled = !state.loading,
                    modifier = Modifier.weight(1f),
                    cornerRadius = 14.dp,
                ) {
                    if (state.loading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                    } else {
                        Text("CONNECT", fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                    }
                }
            }
        }
    }
}
