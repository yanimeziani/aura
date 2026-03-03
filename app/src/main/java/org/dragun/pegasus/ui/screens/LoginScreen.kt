package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.dragun.pegasus.ui.components.glass.*

@Composable
fun LoginScreen(viewModel: LoginViewModel, onLoginSuccess: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val focusManager = LocalFocusManager.current
    var showPassword by remember { mutableStateOf(false) }

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
                        text = "OpenClaw Control Plane",
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
                        leadingIcon = { Icon(Icons.Default.Person, null, tint = MaterialTheme.colorScheme.primary) },
                        modifier = Modifier.fillMaxWidth(),
                    )

                    Spacer(Modifier.height(14.dp))

                    GlassTextField(
                        value = state.password,
                        onValueChange = viewModel::updatePassword,
                        placeholder = "Password",
                        leadingIcon = { Icon(Icons.Default.Lock, null, tint = MaterialTheme.colorScheme.primary) },
                        trailingIcon = {
                            IconButton(onClick = { showPassword = !showPassword }) {
                                Icon(
                                    if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                    contentDescription = "Toggle password",
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                            }
                        },
                        visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                    )

                    state.error?.let {
                        Spacer(Modifier.height(12.dp))
                        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    }

                    Spacer(Modifier.height(24.dp))

                    GlassButton(
                        onClick = { viewModel.login(onLoginSuccess) },
                        enabled = !state.loading,
                        modifier = Modifier.fillMaxWidth(),
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

            Spacer(Modifier.height(32.dp))

            Text(
                text = "dragun.app",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
