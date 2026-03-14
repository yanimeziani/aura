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
import org.dragun.pegasus.ui.components.adaptive.*
import org.dragun.pegasus.ui.components.brutalist.*
import org.dragun.pegasus.ui.theme.BrutalistTheme

@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel = hiltViewModel(),
    onNavigate: (String) -> Unit,
    onLogout: () -> Unit,
) {
    val state by viewModel.state.collectAsState()

    if (state.isBrutalist) {
        BrutalistTheme {
            BrutalistDashboard(state, viewModel, onNavigate, onLogout)
        }
    } else {
        FoldableLayout { isFolded, isLandscape ->
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
                            IconButton(onClick = { viewModel.toggleBrutalist() }) {
                                Icon(Icons.Default.Terminal, "Brutalist Mode", tint = MaterialTheme.colorScheme.primary)
                            }
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

                    Spacer(Modifier.height(16.dp))

                    // Adaptive Content Area (Liquid Glass)
                    if (isLandscape || isFolded) {
                        TwoPaneLayout(state, viewModel, onNavigate)
                    } else {
                        SinglePaneLayout(state, viewModel, onNavigate)
                    }
                }
                
                AgentMessageDialog(state, viewModel)
            }
        }
    }
}

@Composable
fun BrutalistDashboard(
    state: DashboardState,
    viewModel: DashboardViewModel,
    onNavigate: (String) -> Unit,
    onLogout: () -> Unit
) {
    FoldableLayout { isFolded, isLandscape ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .statusBarsPadding()
                .padding(16.dp)
        ) {
            BrutalistHeader(
                title = "PEGASUS",
                subtitle = "OPERATOR: ${state.username}",
                actions = {
                    IconButton(onClick = { viewModel.toggleBrutalist() }) {
                        Icon(Icons.Default.AutoFixHigh, "Liquid Glass Mode")
                    }
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(Icons.Default.Refresh, "Refresh")
                    }
                    IconButton(onClick = { viewModel.logout(onLogout) }) {
                        Icon(Icons.Default.Logout, "Exit")
                    }
                }
            )

            Spacer(Modifier.height(16.dp))

            if (isLandscape || isFolded) {
                // Brutalist Two-Pane
                Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        BrutalistAlerts(state, viewModel)
                        
                        Text("SYSTEM_HEALTH", style = MaterialTheme.typography.labelLarge)
                        BrutalistStatusCard(state)

                        Text("ACTIVE_AGENTS", style = MaterialTheme.typography.labelLarge)
                        BrutalistAgentsList(state, viewModel, onNavigate)
                    }

                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Text("MISSION_CONTROL", style = MaterialTheme.typography.labelLarge)
                        BrutalistActionsGrid(state, viewModel, onNavigate)

                        Text("RESOURCE_USAGE", style = MaterialTheme.typography.labelLarge)
                        BrutalistCosts(state)
                    }
                }
            } else {
                // Brutalist Single-Pane (Z Flip Reachability)
                ReachabilityColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    BrutalistAlerts(state, viewModel)
                    BrutalistStatusCard(state)
                    BrutalistAgentsList(state, viewModel, onNavigate)
                    BrutalistActionsGrid(state, viewModel, onNavigate)
                    BrutalistCosts(state)
                    Spacer(Modifier.height(32.dp))
                }
            }
        }
        AgentMessageDialog(state, viewModel)
    }
}

@Composable
private fun BrutalistAlerts(state: DashboardState, viewModel: DashboardViewModel) {
    if (state.panicActive) {
        BrutalistCard(
            backgroundColor = MaterialTheme.colorScheme.error,
            borderColor = MaterialTheme.colorScheme.onError
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Warning, null, tint = MaterialTheme.colorScheme.onError)
                Spacer(Modifier.width(12.dp))
                Text(
                    "PANIC_MODE_ACTIVE",
                    fontWeight = FontWeight.Black,
                    color = MaterialTheme.colorScheme.onError
                )
                Spacer(Modifier.weight(1f))
                BrutalistButton(
                    onClick = { viewModel.togglePanic() },
                    backgroundColor = MaterialTheme.colorScheme.onError,
                    contentColor = MaterialTheme.colorScheme.error,
                    modifier = Modifier.height(40.dp)
                ) {
                    Text("HALT_OFF", style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
private fun BrutalistStatusCard(state: DashboardState) {
    state.health?.let { health ->
        BrutalistCard {
            Text("STATUS: ${health.status.uppercase()}", fontWeight = FontWeight.Bold)
            Text("UPTIME: ${health.uptime_s}S", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun BrutalistAgentsList(state: DashboardState, viewModel: DashboardViewModel, onNavigate: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        state.agents.forEach { (id, info) ->
            BrutalistCard(onClick = { onNavigate("${Routes.AGENT_STREAM}/$id") }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(id.uppercase(), fontWeight = FontWeight.Black)
                        Text(info.status?.uppercase() ?: "IDLE", style = MaterialTheme.typography.bodySmall)
                    }
                    BrutalistTag(
                        text = "CHAT",
                        color = MaterialTheme.colorScheme.secondary
                    )
                    Spacer(Modifier.width(8.dp))
                    BrutalistTag(
                        text = if (info.status == "running") "STOP" else "START",
                        color = if (info.status == "running") MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                    )
                }
            }
        }
    }
}

@Composable
private fun BrutalistActionsGrid(state: DashboardState, viewModel: DashboardViewModel, onNavigate: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BrutalistButton(onClick = { onNavigate(Routes.HITL) }, modifier = Modifier.weight(1f)) {
                Text("HITL_QUEUE (${state.hitlCount})")
            }
            BrutalistButton(onClick = { onNavigate(Routes.COSTS) }, modifier = Modifier.weight(1f)) {
                Text("COST_LOGS")
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BrutalistButton(onClick = { onNavigate(Routes.TERMINAL) }, modifier = Modifier.weight(1f)) {
                Text("TERMINAL")
            }
            BrutalistButton(
                onClick = { viewModel.togglePanic() },
                modifier = Modifier.weight(1f),
                backgroundColor = if (state.panicActive) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error
            ) {
                Text(if (state.panicActive) "SAFE_BOOT" else "PANIC_HALT")
            }
        }
    }
}

@Composable
private fun BrutalistCosts(state: DashboardState) {
    state.costs?.let { costs ->
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            costs.agents.forEach { (name, entry) ->
                Text("${name.uppercase()}: $${String.format("%.4f", entry.spent_usd)}", style = MaterialTheme.typography.bodySmall)
                // Minimalist Brutalist progress bar
                Box(modifier = Modifier.fillMaxWidth().height(4.dp).background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))) {
                    Box(modifier = Modifier.fillMaxWidth((entry.pct/100f).toFloat()).fillMaxHeight().background(MaterialTheme.colorScheme.primary))
                }
            }
        }
    }
}

// Reusable parts of Liquid Glass Dashboard to keep code clean
@Composable
private fun TwoPaneLayout(state: DashboardState, viewModel: DashboardViewModel, onNavigate: (String) -> Unit) {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Column(
            modifier = Modifier.weight(1.2f).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            DashboardAlerts(state, viewModel)
            state.health?.let { health -> StatusCard("System Health", health.status, "Uptime: ${(health.uptime_s / 60).toInt()} minutes") }
            SectionHeader("Agents")
            AgentsList(state, viewModel, onNavigate)
            Spacer(Modifier.height(24.dp))
        }
        Column(
            modifier = Modifier.weight(0.8f).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            SectionHeader("Quick Actions")
            QuickActionsGrid(state, viewModel, onNavigate)
            state.costs?.let { costs ->
                SectionHeader("Today's Spend")
                costs.agents.forEach { (key, entry) -> CostBar(key, entry.spent_usd, entry.cap_usd, entry.pct) }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SinglePaneLayout(state: DashboardState, viewModel: DashboardViewModel, onNavigate: (String) -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        DashboardAlerts(state, viewModel)
        state.health?.let { health -> StatusCard("System Health", health.status, "Uptime: ${(health.uptime_s / 60).toInt()} minutes") }
        SectionHeader("Agents")
        AgentsList(state, viewModel, onNavigate)
        SectionHeader("Quick Actions")
        QuickActionsGrid(state, viewModel, onNavigate)
        state.costs?.let { costs ->
            SectionHeader("Today's Spend")
            costs.agents.forEach { (key, entry) -> CostBar(key, entry.spent_usd, entry.cap_usd, entry.pct) }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun AgentMessageDialog(state: DashboardState, viewModel: DashboardViewModel) {
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
                ) { Text("Send") }
            },
            dismissButton = {
                TextButton(onClick = viewModel::closeMessageAgent) { Text("Cancel") }
            },
        )
    }
}

// ... the rest of existing helper components like DashboardAlerts, AgentsList, etc.
// (Keeping them defined in the file as per original structure)
@Composable
private fun DashboardAlerts(state: DashboardState, viewModel: DashboardViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        AnimatedVisibility(
            visible = state.panicActive,
            enter = fadeIn() + slideInVertically(initialOffsetY = { -it / 2 }),
            exit = fadeOut() + slideOutVertically(targetOffsetY = { -it / 2 }),
        ) {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Warning, null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(28.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("PANIC MODE ACTIVE", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.error)
                        Text("All agents halted", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    GlassButton(onClick = { viewModel.togglePanic() }) { Text("CLEAR", style = MaterialTheme.typography.labelMedium) }
                }
            }
        }
        AnimatedVisibility(visible = state.error != null) {
            state.error?.let {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Error, null, tint = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.width(8.dp))
                        Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
    }
}

@Composable
private fun AgentsList(state: DashboardState, viewModel: DashboardViewModel, onNavigate: (String) -> Unit) {
    state.agents.forEach { (id, info) ->
        AgentCard(id, info, id == state.primaryAgentId, { onNavigate("${Routes.AGENT_STREAM}/$id") }, { onNavigate("${Routes.AGENT_CHAT}/$id") }, { viewModel.openMessageAgent(id) }, { viewModel.startAgent(id) }, { viewModel.stopAgent(id) })
    }
}

@Composable
private fun QuickActionsGrid(state: DashboardState, viewModel: DashboardViewModel, onNavigate: (String) -> Unit) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        ActionCard(Icons.Default.CheckCircle, "HITL Queue", state.hitlCount, { onNavigate(Routes.HITL) }, Modifier.weight(1f))
        ActionCard(Icons.Default.AttachMoney, "Costs", 0, { onNavigate(Routes.COSTS) }, Modifier.weight(1f))
    }
    Spacer(Modifier.height(12.dp))
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        ActionCard(Icons.Default.Terminal, "Terminal", 0, { onNavigate(Routes.TERMINAL) }, Modifier.weight(1f))
        ActionCard(if (state.panicActive) Icons.Default.Shield else Icons.Default.Warning, if (state.panicActive) "Clear" else "Panic", 0, { viewModel.togglePanic() }, Modifier.weight(1f), !state.panicActive)
    }
}

@Composable private fun SectionHeader(title: String) { Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold) }
@Composable private fun StatusCard(title: String, status: String, subtitle: String) { GlassCard(modifier = Modifier.fillMaxWidth()) { Row(verticalAlignment = Alignment.CenterVertically) { Box(modifier = Modifier.size(48.dp).background(MaterialTheme.colorScheme.primary.copy(0.1f)), contentAlignment = Alignment.Center) { Icon(Icons.Default.CheckCircle, null, tint = MaterialTheme.colorScheme.primary) }; Spacer(Modifier.width(16.dp)); Column { Text(title, fontWeight = FontWeight.Bold); Text(subtitle, style = MaterialTheme.typography.bodySmall) } } } }
@Composable private fun AgentCard(id: String, info: AgentInfo, isPrimary: Boolean, onClick: () -> Unit, onChat: () -> Unit, onMessage: () -> Unit, onStart: () -> Unit, onStop: () -> Unit) { GlassCard(modifier = Modifier.fillMaxWidth(), onClick = onClick) { Row(verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(id, fontWeight = FontWeight.Bold); Text(info.status ?: "idle", style = MaterialTheme.typography.bodySmall) }; Row { IconButton(onClick = onChat) { Icon(Icons.Default.Message, null) }; IconButton(onClick = if (info.status == "running") onStop else onStart) { Icon(if (info.status == "running") Icons.Default.Stop else Icons.Default.PlayArrow, null) } } } } }
@Composable private fun ActionCard(icon: ImageVector, label: String, badge: Int, onClick: () -> Unit, modifier: Modifier, isDestructive: Boolean = false) { GlassCard(modifier = modifier, onClick = onClick) { Column(horizontalAlignment = Alignment.CenterHorizontally) { Icon(icon, null, tint = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary); Text(label, style = MaterialTheme.typography.labelSmall) } } }
@Composable private fun CostBar(label: String, spent: Double, cap: Double, pct: Double) { Column { Text(label, style = MaterialTheme.typography.bodySmall); LinearProgressIndicator(progress = (pct/100f).toFloat(), modifier = Modifier.fillMaxWidth()) } }
