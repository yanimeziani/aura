package org.dragun.pegasus.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import org.dragun.pegasus.domain.model.AgentInfo
import org.dragun.pegasus.ui.Routes
import org.dragun.pegasus.ui.components.glass.*

@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel = hiltViewModel(),
    onNavigate: (String) -> Unit,
    onLogout: () -> Unit,
) {
    val state by viewModel.state.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.background,
                        MaterialTheme.colorScheme.background.copy(alpha = 0.95f),
                    )
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Spacer(Modifier.height(8.dp))

            GlassTopBar(
                title = {
                    Column {
                        Text(
                            "Pegasus",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                        Text(
                            "Cerberus · ${state.username}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(Icons.Default.Refresh, "Refresh", tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = { onNavigate(Routes.SETTINGS) }) {
                        Icon(Icons.Default.Settings, "Settings", tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = { viewModel.logout(onLogout) }) {
                        Icon(Icons.Default.Logout, "Logout", tint = MaterialTheme.colorScheme.primary)
                    }
                },
            )

            AnimatedVisibility(
                visible = state.panicActive,
                enter = fadeIn() + slideInVertically(initialOffsetY = { -it / 2 }),
                exit = fadeOut() + slideOutVertically(targetOffsetY = { -it / 2 }),
            ) {
                GlassCard(
                    modifier = Modifier.fillMaxWidth(),
                    cornerRadius = 16.dp,
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Default.Warning,
                            null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(28.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                "PANIC MODE ACTIVE",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.error,
                            )
                            Text(
                                "All agents halted",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        GlassButton(
                            onClick = { viewModel.togglePanic() },
                            cornerRadius = 10.dp,
                        ) {
                            Text("CLEAR", style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }

            AnimatedVisibility(
                visible = state.error != null,
                enter = fadeIn() + slideInVertically(initialOffsetY = { -it / 3 }),
                exit = fadeOut(),
            ) {
                state.error?.let {
                    GlassCard(
                        modifier = Modifier.fillMaxWidth(),
                        cornerRadius = 16.dp,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Error, null, tint = MaterialTheme.colorScheme.error)
                            Spacer(Modifier.width(8.dp))
                            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }

            state.health?.let { health ->
                StatusCard(
                    title = "System Health",
                    status = health.status,
                    subtitle = "Uptime: ${(health.uptime_s / 60).toInt()} minutes",
                )
            }

            SectionHeader("Agents")
            val orderedAgentIds = if (state.primaryAgentId != null) {
                listOf(state.primaryAgentId!!) + state.agents.keys.filter { it != state.primaryAgentId }
            } else {
                state.agents.keys.toList()
            }
            orderedAgentIds.forEach { id ->
                state.agents[id]?.let { info ->
                    AgentCard(
                        id = id,
                        info = info,
                        isPrimary = id == state.primaryAgentId,
                        onClick = { onNavigate("${Routes.AGENT_STREAM}/$id") },
                        onChat = { onNavigate("${Routes.AGENT_CHAT}/$id") },
                        onMessage = { viewModel.openMessageAgent(id) },
                        onStart = { viewModel.startAgent(id) },
                        onStop = { viewModel.stopAgent(id) },
                    )
                }
            }
            if (state.agents.isEmpty()) {
                if (state.loading) {
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(20.dp),
                                strokeWidth = 2.dp,
                            )
                            Spacer(Modifier.width(12.dp))
                            Text(
                                "Loading agents…",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                } else {
                    GlassCard(modifier = Modifier.fillMaxWidth()) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Default.CloudOff, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(8.dp))
                            Text(
                                "No agents connected",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            SectionHeader("Quick Actions")
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                ActionCard(
                    icon = Icons.Default.CheckCircle,
                    label = "HITL Queue",
                    badge = state.hitlCount,
                    onClick = { onNavigate(Routes.HITL) },
                    modifier = Modifier.weight(1f),
                )
                ActionCard(
                    icon = Icons.Default.AttachMoney,
                    label = "Costs",
                    onClick = { onNavigate(Routes.COSTS) },
                    modifier = Modifier.weight(1f),
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                ActionCard(
                    icon = Icons.Default.Terminal,
                    label = "Terminal",
                    onClick = { onNavigate(Routes.TERMINAL) },
                    modifier = Modifier.weight(1f),
                )
                ActionCard(
                    icon = if (state.panicActive) Icons.Default.Shield else Icons.Default.Warning,
                    label = if (state.panicActive) "Clear Panic" else "Panic",
                    onClick = { viewModel.togglePanic() },
                    modifier = Modifier.weight(1f),
                    isDestructive = !state.panicActive,
                )
            }

            state.costs?.let { costs ->
                SectionHeader("Today's Spend")
                costs.agents.forEach { (key, entry) ->
                    CostBar(label = key, spent = entry.spent_usd, cap = entry.cap_usd, pct = entry.pct)
                }
            }

            Spacer(Modifier.height(24.dp))
        }

        state.messageAgentId?.let { agentId ->
            var messageText by remember(agentId) { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = viewModel::closeMessageAgent,
                title = { Text("Message agent: $agentId") },
                text = {
                    OutlinedTextField(
                        value = messageText,
                        onValueChange = { messageText = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("What should the agent do?") },
                        minLines = 2,
                    )
                },
                confirmButton = {
                    TextButton(
                        onClick = {
                            if (messageText.isNotBlank()) {
                                viewModel.submitTask(agentId, messageText.trim()) {
                                    viewModel.closeMessageAgent()
                                }
                            }
                        },
                    ) {
                        Text("Send")
                    }
                },
                dismissButton = {
                    TextButton(onClick = viewModel::closeMessageAgent) {
                        Text("Cancel")
                    }
                },
            )
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onBackground,
    )
}

@Composable
private fun StatusCard(title: String, status: String, subtitle: String) {
    val isHealthy = status == "ok"
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(
                        color = if (isHealthy) MaterialTheme.colorScheme.secondary.copy(alpha = 0.15f)
                        else MaterialTheme.colorScheme.error.copy(alpha = 0.15f),
                        shape = MaterialTheme.shapes.medium
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (isHealthy) Icons.Default.CheckCircle else Icons.Default.Error,
                    null,
                    tint = if (isHealthy) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error,
                )
            }
            Spacer(Modifier.width(16.dp))
            Column {
                Text(title, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleSmall)
                Text(
                    subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AgentCard(
    id: String,
    info: AgentInfo,
    isPrimary: Boolean = false,
    onClick: () -> Unit,
    onChat: () -> Unit,
    onMessage: () -> Unit,
    onStart: () -> Unit,
    onStop: () -> Unit,
) {
    val statusColor = when (info.status) {
        "running" -> MaterialTheme.colorScheme.secondary
        "idle" -> MaterialTheme.colorScheme.onSurfaceVariant
        "error" -> MaterialTheme.colorScheme.error
        "waiting_hitl" -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    GlassCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
        cornerRadius = 18.dp,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .background(
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        shape = MaterialTheme.shapes.medium
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (id.contains("devsecops")) Icons.Default.Security else Icons.Default.SmartToy,
                    null,
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(id, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.titleSmall)
                    if (isPrimary) {
                        Spacer(Modifier.width(6.dp))
                        Surface(
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
                            shape = MaterialTheme.shapes.small,
                        ) {
                            Text(
                                "Main",
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
                Text(
                    info.current_task ?: "No active task",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
            Spacer(Modifier.width(8.dp))
            Surface(
                color = statusColor.copy(alpha = 0.15f),
                shape = MaterialTheme.shapes.small,
            ) {
                Text(
                    info.status ?: "unknown",
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
                    style = MaterialTheme.typography.labelSmall,
                    color = statusColor,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
        ) {
            GlassButton(
                onClick = onChat,
                cornerRadius = 10.dp,
            ) {
                Icon(Icons.Default.Message, null, Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text("Chat", style = MaterialTheme.typography.labelSmall)
            }
            Spacer(Modifier.width(8.dp))
            GlassButton(
                onClick = onMessage,
                cornerRadius = 10.dp,
            ) {
                Icon(Icons.Default.Send, null, Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text("Message", style = MaterialTheme.typography.labelSmall)
            }
            Spacer(Modifier.width(8.dp))
            if (info.status == "running") {
                GlassButton(
                    onClick = onStop,
                    cornerRadius = 10.dp,
                ) {
                    Icon(Icons.Default.Stop, null, Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Stop", style = MaterialTheme.typography.labelSmall)
                }
            } else {
                GlassButton(
                    onClick = onStart,
                    cornerRadius = 10.dp,
                ) {
                    Icon(Icons.Default.PlayArrow, null, Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Start", style = MaterialTheme.typography.labelSmall)
                }
            }
            Spacer(Modifier.width(8.dp))
            GlassButton(
                onClick = onClick,
                cornerRadius = 10.dp,
            ) {
                Icon(Icons.Default.Terminal, null, Modifier.size(16.dp))
                Spacer(Modifier.width(4.dp))
                Text("Stream", style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun ActionCard(
    icon: ImageVector,
    label: String,
    badge: Int = 0,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isDestructive: Boolean = false,
) {
    val tint = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary

    GlassCard(
        modifier = modifier,
        onClick = onClick,
        cornerRadius = 16.dp,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (badge > 0) {
                BadgedBox(
                    badge = {
                        Badge(
                            containerColor = MaterialTheme.colorScheme.error,
                            contentColor = MaterialTheme.colorScheme.onError,
                        ) {
                            Text("$badge")
                        }
                    }
                ) {
                    Icon(icon, null, tint = tint, modifier = Modifier.size(28.dp))
                }
            } else {
                Icon(icon, null, tint = tint, modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.height(8.dp))
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun CostBar(label: String, spent: Double, cap: Double, pct: Double) {
    val color = when {
        pct >= 100 -> MaterialTheme.colorScheme.error
        pct >= 80 -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.secondary
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(
                label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.Medium,
            )
            Text(
                "$${String.format("%.4f", spent)} / $${String.format("%.2f", cap)}",
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Bold,
                color = color,
            )
        }
        Spacer(Modifier.height(6.dp))
        GlassSurface(modifier = Modifier.fillMaxWidth().height(8.dp), cornerRadius = 4.dp) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth((pct / 100.0).toFloat().coerceIn(0f, 1f))
                    .background(
                        color = color,
                        shape = MaterialTheme.shapes.small
                    )
            )
        }
    }
}
