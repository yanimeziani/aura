package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.store.SessionStore
import javax.inject.Inject

data class SettingsState(
    val apiUrl: String = "https://pegasus.meziani.org",
    val sshHost: String = "89.116.170.202",
    val sshPort: String = "22",
    val sshUser: String = "root",
    val saved: Boolean = false,
)

@HiltViewModel
class SettingsViewModel @Inject constructor(private val session: SessionStore) : ViewModel() {
    private val _state = MutableStateFlow(SettingsState())
    val state: StateFlow<SettingsState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            session.apiUrl.first()?.let { url -> _state.update { it.copy(apiUrl = url) } }
            session.sshHost.first()?.let { host -> _state.update { it.copy(sshHost = host) } }
        }
    }

    fun updateApiUrl(v: String) { _state.update { it.copy(apiUrl = v, saved = false) } }
    fun updateSshHost(v: String) { _state.update { it.copy(sshHost = v, saved = false) } }
    fun updateSshPort(v: String) { _state.update { it.copy(sshPort = v, saved = false) } }
    fun updateSshUser(v: String) { _state.update { it.copy(sshUser = v, saved = false) } }

    fun save() {
        viewModelScope.launch {
            val s = _state.value
            session.saveServerConfig(
                s.apiUrl,
                s.sshHost,
                s.sshPort.toIntOrNull() ?: 22,
                s.sshUser,
            )
            _state.update { it.copy(saved = true) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(viewModel: SettingsViewModel = hiltViewModel(), onBack: () -> Unit) {
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.save() }) {
                        Icon(Icons.Default.Save, "Save")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("OpenClaw API", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            OutlinedTextField(
                value = state.apiUrl,
                onValueChange = viewModel::updateApiUrl,
                label = { Text("API URL") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            HorizontalDivider()

            Text("SSH Connection", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            OutlinedTextField(
                value = state.sshHost,
                onValueChange = viewModel::updateSshHost,
                label = { Text("Host / IP") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = state.sshPort,
                    onValueChange = viewModel::updateSshPort,
                    label = { Text("Port") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                OutlinedTextField(
                    value = state.sshUser,
                    onValueChange = viewModel::updateSshUser,
                    label = { Text("User") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
            }

            if (state.saved) {
                Text(
                    "Settings saved",
                    color = MaterialTheme.colorScheme.secondary,
                    fontWeight = FontWeight.Bold,
                )
            }

            Spacer(Modifier.height(16.dp))

            Button(
                onClick = { viewModel.save() },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Save Settings")
            }

            Spacer(Modifier.height(32.dp))
            Text(
                "Pegasus v0.1.0-alpha",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "dragun.app / OpenClaw",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
