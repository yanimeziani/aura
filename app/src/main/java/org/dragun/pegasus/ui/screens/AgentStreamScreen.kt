package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.repository.AgentStreamEvent
import org.dragun.pegasus.data.repository.AgentStreamRepository
import javax.inject.Inject

data class AgentStreamState(
    val agentId: String = "",
    val lines: List<String> = emptyList(),
    val connected: Boolean = false,
    val status: String = "idle",
    val isStarting: Boolean = false,
    val isStopping: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class AgentStreamViewModel @Inject constructor(
    private val streamRepo: AgentStreamRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(AgentStreamState())
    val state: StateFlow<AgentStreamState> = _state.asStateFlow()

    private var streamJob: kotlinx.coroutines.Job? = null

    fun connect(agentId: String) {
        _state.update { it.copy(agentId = agentId, lines = emptyList(), error = null) }
        
        streamJob?.cancel()
        streamJob = viewModelScope.launch {
            streamRepo.streamAgentOutput(agentId).collect { event ->
                when (event) {
                    is AgentStreamEvent.Connected -> {
                        _state.update { it.copy(connected = true, status = "connected") }
                    }
                    is AgentStreamEvent.Output -> {
                        _state.update { it.copy(lines = it.lines + event.text) }
                    }
                    is AgentStreamEvent.Status -> {
                        _state.update { it.copy(status = event.status) }
                    }
                    is AgentStreamEvent.Error -> {
                        _state.update { it.copy(error = event.message, connected = false) }
                    }
                    is AgentStreamEvent.Disconnected -> {
                        _state.update { it.copy(connected = false, status = "disconnected") }
                    }
                }
            }
        }
    }

    fun startAgent() {
        val agentId = _state.value.agentId
        if (agentId.isBlank()) return

        viewModelScope.launch {
            _state.update { it.copy(isStarting = true, error = null) }
            val result = streamRepo.startAgent(agentId)
            result.fold(
                onSuccess = {
                    _state.update { it.copy(isStarting = false, status = "starting") }
                    connect(agentId)
                },
                onFailure = { e ->
                    _state.update { it.copy(isStarting = false, error = e.message) }
                }
            )
        }
    }

    fun stopAgent() {
        val agentId = _state.value.agentId
        if (agentId.isBlank()) return

        viewModelScope.launch {
            _state.update { it.copy(isStopping = true, error = null) }
            val result = streamRepo.stopAgent(agentId)
            result.fold(
                onSuccess = {
                    _state.update { it.copy(isStopping = false, status = "stopping") }
                    streamJob?.cancel()
                    _state.update { it.copy(connected = false) }
                },
                onFailure = { e ->
                    _state.update { it.copy(isStopping = false, error = e.message) }
                }
            )
        }
    }

    fun clearOutput() {
        _state.update { it.copy(lines = emptyList()) }
    }

    fun disconnect() {
        streamJob?.cancel()
        _state.update { it.copy(connected = false, status = "disconnected") }
    }

    override fun onCleared() {
        super.onCleared()
        streamJob?.cancel()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentStreamScreen(
    agentId: String,
    viewModel: AgentStreamViewModel = hiltViewModel(),
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val listState = rememberLazyListState()

    LaunchedEffect(agentId) {
        viewModel.connect(agentId)
    }

    LaunchedEffect(state.lines.size) {
        if (state.lines.isNotEmpty()) {
            listState.animateScrollToItem(state.lines.size - 1)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Agent: $agentId")
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                if (state.connected) Icons.Default.Cloud else Icons.Default.CloudOff,
                                null,
                                modifier = Modifier.size(14.dp),
                                tint = if (state.connected) MaterialTheme.colorScheme.secondary 
                                       else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Spacer(Modifier.width(4.dp))
                            Text(
                                state.status,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = {
                        viewModel.disconnect()
                        onBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.clearOutput() }) {
                        Icon(Icons.Default.ClearAll, "Clear")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Color(0xFF0D1117)),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF161B22))
                    .padding(8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Button(
                    onClick = { viewModel.startAgent() },
                    enabled = !state.isStarting && !state.connected,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.secondary,
                    ),
                ) {
                    if (state.isStarting) {
                        CircularProgressIndicator(
                            Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onSecondary,
                        )
                    } else {
                        Icon(Icons.Default.PlayArrow, null, Modifier.size(18.dp))
                    }
                    Spacer(Modifier.width(4.dp))
                    Text("Start")
                }

                Button(
                    onClick = { viewModel.stopAgent() },
                    enabled = !state.isStopping && state.connected,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error,
                    ),
                ) {
                    if (state.isStopping) {
                        CircularProgressIndicator(
                            Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onError,
                        )
                    } else {
                        Icon(Icons.Default.Stop, null, Modifier.size(18.dp))
                    }
                    Spacer(Modifier.width(4.dp))
                    Text("Stop")
                }
            }

            state.error?.let { error ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                    ),
                ) {
                    Row(modifier = Modifier.padding(8.dp)) {
                        Icon(
                            Icons.Default.Error,
                            null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            error,
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }
            }

            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                items(state.lines) { line ->
                    Text(
                        text = line,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = Color(0xFFE6EDF3),
                        modifier = Modifier.padding(vertical = 1.dp),
                    )
                }

                if (state.connected) {
                    item {
                        Row(
                            modifier = Modifier.padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(12.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.secondary,
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                "Streaming...",
                                fontFamily = FontFamily.Monospace,
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.secondary,
                            )
                        }
                    }
                }
            }
        }
    }
}
