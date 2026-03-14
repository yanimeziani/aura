package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
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
import org.dragun.pegasus.domain.model.CostStatus
import javax.inject.Inject

@HiltViewModel
class CostsViewModel @Inject constructor(private val api: CerberusApi) : ViewModel() {
    private val _state = MutableStateFlow<CostStatus?>(null)
    val state: StateFlow<CostStatus?> = _state.asStateFlow()

    private val _loading = MutableStateFlow(true)
    val loading: StateFlow<Boolean> = _loading.asStateFlow()

    init { refresh() }

    fun refresh() {
        viewModelScope.launch {
            _loading.update { true }
            try {
                val resp = api.costStatus()
                _state.value = resp.body()
            } catch (_: Exception) {}
            _loading.update { false }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CostsScreen(viewModel: CostsViewModel = hiltViewModel(), onBack: () -> Unit) {
    val costs by viewModel.state.collectAsState()
    val loading by viewModel.loading.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Cost Tracking") },
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
        if (loading && costs == null) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                costs?.let { c ->
                    Text("Date: ${c.date}", style = MaterialTheme.typography.titleSmall)

                    if (c.panic_active) {
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.error)) {
                            Text(
                                "PANIC MODE ACTIVE",
                                modifier = Modifier.padding(16.dp),
                                color = MaterialTheme.colorScheme.onError,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }

                    c.agents.forEach { (key, entry) ->
                        val color = when (entry.status) {
                            "exceeded" -> MaterialTheme.colorScheme.error
                            "warning" -> MaterialTheme.colorScheme.tertiary
                            else -> MaterialTheme.colorScheme.secondary
                        }

                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Row(
                                    Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                ) {
                                    Text(key, fontWeight = FontWeight.Bold)
                                    Surface(
                                        color = color.copy(alpha = 0.15f),
                                        shape = MaterialTheme.shapes.small,
                                    ) {
                                        Text(
                                            entry.status,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                            style = MaterialTheme.typography.labelSmall,
                                            color = color,
                                            fontWeight = FontWeight.Bold,
                                        )
                                    }
                                }
                                Spacer(Modifier.height(8.dp))
                                Text(
                                    "$${String.format("%.4f", entry.spent_usd)} / $${String.format("%.2f", entry.cap_usd)}",
                                    style = MaterialTheme.typography.headlineSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = color,
                                )
                                Spacer(Modifier.height(4.dp))
                                LinearProgressIndicator(
                                    progress = { (entry.pct / 100.0).toFloat().coerceIn(0f, 1f) },
                                    modifier = Modifier.fillMaxWidth().height(8.dp),
                                    color = color,
                                    trackColor = MaterialTheme.colorScheme.surfaceVariant,
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    "${String.format("%.1f", entry.pct)}% of daily cap",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                } ?: Text("No cost data available", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
