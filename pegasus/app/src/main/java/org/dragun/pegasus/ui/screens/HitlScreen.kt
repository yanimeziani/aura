package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.api.CerberusApi
import org.dragun.pegasus.domain.model.HitlItem
import javax.inject.Inject

data class HitlState(
    val items: List<HitlItem> = emptyList(),
    val loading: Boolean = true,
    val error: String? = null,
    val expandedId: String? = null,
)

@HiltViewModel
class HitlViewModel @Inject constructor(private val api: CerberusApi) : ViewModel() {
    private val _state = MutableStateFlow(HitlState())
    val state: StateFlow<HitlState> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                val resp = api.hitlQueue()
                _state.update { it.copy(items = resp.body()?.items ?: emptyList(), loading = false) }
            } catch (e: Exception) {
                _state.update { it.copy(loading = false, error = e.message) }
            }
        }
    }

    fun approve(taskId: String) {
        viewModelScope.launch {
            try { api.approve(taskId); refresh() }
            catch (e: Exception) { _state.update { it.copy(error = "Approve failed: ${e.message}") } }
        }
    }

    fun reject(taskId: String) {
        viewModelScope.launch {
            try { api.reject(taskId); refresh() }
            catch (e: Exception) { _state.update { it.copy(error = "Reject failed: ${e.message}") } }
        }
    }

    fun toggleExpand(taskId: String) {
        _state.update {
            it.copy(expandedId = if (it.expandedId == taskId) null else taskId)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HitlScreen(viewModel: HitlViewModel = hiltViewModel(), onBack: () -> Unit) {
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("HITL Approval Queue") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.refresh() }) {
                        Icon(Icons.Default.Refresh, "Refresh")
                    }
                },
            )
        },
    ) { padding ->
        if (state.loading) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (state.items.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.CheckCircle, null, tint = MaterialTheme.colorScheme.secondary, modifier = Modifier.size(48.dp))
                    Spacer(Modifier.height(8.dp))
                    Text("No pending approvals", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                items(state.items, key = { it.task_id }) { item ->
                    HitlCard(
                        item = item,
                        expanded = state.expandedId == item.task_id,
                        onToggle = { viewModel.toggleExpand(item.task_id) },
                        onApprove = { viewModel.approve(item.task_id) },
                        onReject = { viewModel.reject(item.task_id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun HitlCard(
    item: HitlItem,
    expanded: Boolean,
    onToggle: () -> Unit,
    onApprove: () -> Unit,
    onReject: () -> Unit,
) {
    val riskColor = when (item.risk_label) {
        "SAFE" -> MaterialTheme.colorScheme.secondary
        "BLOCKED" -> MaterialTheme.colorScheme.error
        else -> MaterialTheme.colorScheme.tertiary
    }

    Card(
        onClick = onToggle,
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(item.action, fontWeight = FontWeight.Bold)
                    Text(
                        "${item.agent_id} | ${item.blast_radius}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                item.risk_label?.let {
                    Surface(color = riskColor.copy(alpha = 0.15f), shape = MaterialTheme.shapes.small) {
                        Text(
                            it,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelSmall,
                            color = riskColor,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }

            if (expanded) {
                Spacer(Modifier.height(8.dp))
                HorizontalDivider()
                Spacer(Modifier.height(8.dp))

                item.risk_note?.let {
                    Text("Risk: $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(4.dp))
                }
                item.diff_preview?.let {
                    Surface(
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        shape = MaterialTheme.shapes.small,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            it,
                            modifier = Modifier.padding(8.dp),
                            style = MaterialTheme.typography.bodySmall,
                            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                }
                Text(
                    "Reversible: ${if (item.reversible) "yes" else "NO"}",
                    style = MaterialTheme.typography.bodySmall,
                )
                Spacer(Modifier.height(12.dp))

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    OutlinedButton(
                        onClick = onReject,
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    ) { Text("Reject") }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        onClick = onApprove,
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary),
                    ) { Text("Approve") }
                }
            }
        }
    }
}
