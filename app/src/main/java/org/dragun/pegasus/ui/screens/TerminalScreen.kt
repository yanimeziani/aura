package org.dragun.pegasus.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.shell.PegasusShell
import org.dragun.pegasus.data.ssh.SshClientWrapper
import org.dragun.pegasus.data.store.SessionStore
import javax.inject.Inject

data class TermLine(val text: String, val isCommand: Boolean = false, val isError: Boolean = false)

data class TerminalState(
    val lines: List<TermLine> = listOf(TermLine("Pegasus Terminal — type 'help' for commands")),
    val input: String = "",
    val connected: Boolean = false,
    val connecting: Boolean = false,
    val sshHost: String = "",
    val sshUser: String = "root",
    val shellMode: Boolean = true,
)

@HiltViewModel
class TerminalViewModel @Inject constructor(
    private val ssh: SshClientWrapper,
    private val session: SessionStore,
    private val shell: PegasusShell,
) : ViewModel() {

    private val _state = MutableStateFlow(TerminalState())
    val state: StateFlow<TerminalState> = _state.asStateFlow()

    init {
        shell.initialize()
        viewModelScope.launch {
            session.sshHost.collect { host ->
                _state.update { it.copy(sshHost = host ?: "") }
            }
        }
    }

    fun updateInput(input: String) { _state.update { it.copy(input = input) } }

    fun execute() {
        val cmd = _state.value.input.trim()
        if (cmd.isBlank()) return
        _state.update { it.copy(input = "") }

        appendLine(TermLine("$ $cmd", isCommand = true))

        when {
            cmd == "help" -> showHelp()
            cmd == "shell" -> _state.update { it.copy(shellMode = true, connected = false) }
            cmd == "ssh" -> _state.update { it.copy(shellMode = false) }
            cmd == "mode" -> appendLine(TermLine("Current mode: ${if (_state.value.shellMode) "shell" else "ssh"}"))
            cmd == "connect" || cmd.startsWith("connect ") -> connect(cmd)
            cmd == "disconnect" -> disconnect()
            cmd == "clear" -> _state.update { it.copy(lines = emptyList()) }
            _state.value.connected -> runRemote(cmd)
            _state.value.shellMode -> runLocal(cmd)
            else -> appendLine(TermLine("Not connected. Type 'connect' or use shell mode.", isError = true))
        }
    }

    private fun showHelp() {
        val help = """
            Pegasus Terminal Commands:
            
            Shell Mode (built-in):
              help              Show this help
              shell             Switch to shell mode
              ssh               Switch to SSH mode
              mode              Show current mode
              clear             Clear screen
            
            SSH Mode:
              connect [host]    Connect to SSH server
              disconnect        Disconnect from SSH
              
            Both modes:
              exit              Disconnect and exit
        """.trimIndent()
        appendLine(TermLine(help))
    }

    private fun connect(cmd: String) {
        _state.update { it.copy(shellMode = false) }
        val parts = cmd.split(" ")
        val host = if (parts.size > 1) parts[1] else _state.value.sshHost
        val user = if (parts.size > 2) parts[2] else _state.value.sshUser

        if (host.isBlank()) {
            appendLine(TermLine("Usage: connect <host> [user]", isError = true))
            return
        }

        _state.update { it.copy(connecting = true) }
        appendLine(TermLine("Connecting to $user@$host..."))

        viewModelScope.launch {
            try {
                ssh.connect(host, 22, user)
                _state.update { it.copy(connected = true, connecting = false) }
                appendLine(TermLine("Connected to $user@$host (SSH mode)"))
            } catch (e: Exception) {
                _state.update { it.copy(connecting = false) }
                appendLine(TermLine("Connection failed: ${e.message}", isError = true))
            }
        }
    }

    private fun disconnect() {
        ssh.close()
        _state.update { it.copy(connected = false) }
        appendLine(TermLine("Disconnected."))
    }

    private fun runRemote(cmd: String) {
        viewModelScope.launch {
            try {
                val result = ssh.exec(cmd)
                if (result.stdout.isNotBlank()) appendLine(TermLine(result.stdout))
                if (result.stderr.isNotBlank()) appendLine(TermLine(result.stderr, isError = true))
                if (result.stdout.isBlank() && result.stderr.isBlank()) {
                    appendLine(TermLine("(exit ${result.exitCode})"))
                }
            } catch (e: Exception) {
                appendLine(TermLine("Error: ${e.message}", isError = true))
            }
        }
    }

    private fun runLocal(cmd: String) {
        viewModelScope.launch {
            val result = shell.execute(cmd)
            result.fold(
                onSuccess = { output ->
                    if (output.isNotBlank()) appendLine(TermLine(output))
                },
                onFailure = { e ->
                    appendLine(TermLine("Error: ${e.message}", isError = true))
                }
            )
        }
    }

    private fun appendLine(line: TermLine) {
        _state.update { it.copy(lines = it.lines + line) }
    }

    override fun onCleared() {
        super.onCleared()
        shell.cleanup()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TerminalScreen(viewModel: TerminalViewModel = hiltViewModel(), onBack: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val listState = rememberLazyListState()

    LaunchedEffect(state.lines.size) {
        if (state.lines.isNotEmpty()) listState.animateScrollToItem(state.lines.size - 1)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Terminal")
                        Spacer(Modifier.width(8.dp))
                        Icon(
                            if (state.connected) Icons.Default.Link else Icons.Default.LinkOff,
                            null,
                            tint = if (state.connected) MaterialTheme.colorScheme.secondary
                                   else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
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
            LazyColumn(
                state = listState,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                items(state.lines) { line ->
                    Text(
                        text = line.text,
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp,
                        color = when {
                            line.isError -> Color(0xFFF85149)
                            line.isCommand -> Color(0xFF58A6FF)
                            else -> Color(0xFFE6EDF3)
                        },
                        fontWeight = if (line.isCommand) FontWeight.Bold else FontWeight.Normal,
                        modifier = Modifier.padding(vertical = 1.dp),
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF161B22))
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    if (state.connected) "$ " else "> ",
                    fontFamily = FontFamily.Monospace,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                )
                TextField(
                    value = state.input,
                    onValueChange = viewModel::updateInput,
                    modifier = Modifier.weight(1f),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedTextColor = Color(0xFFE6EDF3),
                        unfocusedTextColor = Color(0xFFE6EDF3),
                        cursorColor = MaterialTheme.colorScheme.primary,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                    ),
                    textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace, fontSize = 13.sp),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { viewModel.execute() }),
                    placeholder = {
                        Text(
                            if (state.connected) "command..." else "type 'connect' to start",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 13.sp,
                            color = Color(0xFF8B949E),
                        )
                    },
                )
                IconButton(onClick = { viewModel.execute() }, enabled = !state.connecting) {
                    if (state.connecting) {
                        CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                    } else {
                        Icon(Icons.AutoMirrored.Filled.Send, "Send", tint = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
    }
}
