package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import org.dragun.pegasus.ui.Routes

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel = hiltViewModel(),
    onNavigate: (String) -> Unit,
    onLogout: () -> Unit,
) {
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Pegasus", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "OpenClaw — ${state.username}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(Icons.Default.Refresh, "Refresh")
                    }
                    IconButton(onClick = { onNavigate(Routes.SETTINGS) }) {
                        Icon(Icons.Default.Settings, "Settings")
                    }
                    IconButton(onClick = { viewModel.logout(onLogout) }) {
                        Icon(Icons.Default.Logout, "Logout")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (state.panicActive) {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Default.Warning, null, tint = MaterialTheme.colorScheme.onError)
                        Spacer(Modifier.width(8.dp))
                        Text(
                            "PANIC MODE ACTIVE",
                            color = MaterialTheme.colorScheme.onError,
                            fontWeight = FontWeight.Bold,
                        )
                        Spacer(Modifier.weight(1f))
                        TextButton(
                            onClick = { viewModel.togglePanic() },
                            colors = ButtonDefaults.textButtonColors(
                                contentColor = MaterialTheme.colorScheme.onError,
                            ),
                        ) { Text("CLEAR") }
                    }
                }
            }

            state.error?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }

            // System health
            state.health?.let { health ->
                StatusCard(
                    title = "System",
                    status = health.status,
                    subtitle = "Uptime: ${(health.uptime_s / 60).toInt()}m",
                )
            }

            // Agents
            Text("Agents", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            state.agents.forEach { (id, info) ->
                AgentCard(
                    id = id,
                    info = info,
                    onClick = { onNavigate("${Routes.AGENT_STREAM}/$id") },
                    onStart = { viewModel.startAgent(id) },
                    onStop = { viewModel.stopAgent(id) },
                )
            }
            if (state.agents.isEmpty() && !state.loading) {
                Text(
                    "No agents connected yet",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            // Quick nav cards
            Text("Actions", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NavCard(
                    icon = Icons.Default.CheckCircle,
                    label = "HITL Queue",
                    badge = state.hitlCount,
                    onClick = { onNavigate(Routes.HITL) },
                    modifier = Modifier.weight(1f),
                )
                NavCard(
                    icon = Icons.Default.AttachMoney,
                    label = "Costs",
                    onClick = { onNavigate(Routes.COSTS) },
                    modifier = Modifier.weight(1f),
                )
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NavCard(
                    icon = Icons.Default.Terminal,
                    label = "Terminal",
                    onClick = { onNavigate(Routes.TERMINAL) },
                    modifier = Modifier.weight(1f),
                )
                NavCard(
                    icon = Icons.Default.Warning,
                    label = if (state.panicActive) "Clear Panic" else "Panic",
                    onClick = { viewModel.togglePanic() },
                    modifier = Modifier.weight(1f),
                    isDestructive = !state.panicActive,
                )
            }

            // Costs summary
            state.costs?.let { costs ->
                Text("Today's Spend", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                costs.agents.forEach { (key, entry) ->
                    CostBar(label = key, spent = entry.spent_usd, cap = entry.cap_usd, pct = entry.pct)
                }
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun StatusCard(title: String, status: String, subtitle: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.CheckCircle,
                null,
                tint = if (status == "ok") MaterialTheme.colorScheme.secondary
                       else MaterialTheme.colorScheme.error,
            )
            Spacer(Modifier.width(12.dp))
            Column {
                Text(title, fontWeight = FontWeight.Bold)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun AgentCard(
    id: String,
    info: org.dragun.pegasus.domain.model.AgentInfo,
    onClick: () -> Unit,
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
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        onClick = onClick,
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    if (id.contains("devsecops")) Icons.Default.Security else Icons.Default.TrendingUp,
                    null,
                    tint = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(id, fontWeight = FontWeight.Bold)
                    Text(
                        info.current_task ?: "No active task",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Surface(
                    color = statusColor.copy(alpha = 0.15f),
                    shape = MaterialTheme.shapes.small,
                ) {
                    Text(
                        info.status ?: "unknown",
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = statusColor,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                if (info.status == "running") {
                    TextButton(
                        onClick = onStop,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.error,
                        ),
                    ) {
                        Icon(Icons.Default.Stop, null, Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Stop", style = MaterialTheme.typography.labelSmall)
                    }
                } else {
                    TextButton(
                        onClick = onStart,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.secondary,
                        ),
                    ) {
                        Icon(Icons.Default.PlayArrow, null, Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Start", style = MaterialTheme.typography.labelSmall)
                    }
                }
                Spacer(Modifier.width(8.dp))
                TextButton(onClick = onClick) {
                    Icon(Icons.Default.Terminal, null, Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Stream", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
private fun NavCard(
    icon: ImageVector,
    label: String,
    badge: Int = 0,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isDestructive: Boolean = false,
) {
    val containerColor = if (isDestructive) MaterialTheme.colorScheme.error.copy(alpha = 0.12f)
                         else MaterialTheme.colorScheme.surface
    Card(
        onClick = onClick,
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = containerColor),
    ) {
        Column(
            modifier = Modifier.padding(16.dp).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (badge > 0) {
                BadgedBox(badge = { Badge { Text("$badge") } }) {
                    Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
                }
            } else {
                Icon(
                    icon, null,
                    tint = if (isDestructive) MaterialTheme.colorScheme.error
                           else MaterialTheme.colorScheme.primary,
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
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
            Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                "$${String.format("%.4f", spent)} / $${String.format("%.2f", cap)}",
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Bold,
                color = color,
            )
        }
        LinearProgressIndicator(
            progress = { (pct / 100.0).toFloat().coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth().height(6.dp),
            color = color,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}
