package org.dragun.pegasus.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import org.dragun.pegasus.domain.model.ChatMessage
import org.dragun.pegasus.domain.model.ChatRole
import org.dragun.pegasus.ui.components.glass.GlassCard
import org.dragun.pegasus.ui.components.glass.GlassTopBar
import org.dragun.pegasus.ui.components.adaptive.FoldableLayout
import org.dragun.pegasus.ui.components.adaptive.ReachabilityColumn

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentChatScreen(
    agentId: String,
    viewModel: AgentChatViewModel = hiltViewModel(),
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val listState = rememberLazyListState()
    var inputText by remember(agentId) { mutableStateOf("") }

    LaunchedEffect(agentId) {
        viewModel.setAgent(agentId)
    }

    LaunchedEffect(state.messages.size, state.pendingAssistantText) {
        val last = state.messages.size + if (state.pendingAssistantText.isNotEmpty()) 1 else 0
        if (last > 0) listState.animateScrollToItem(last - 1)
    }

    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? ->
        uri?.let { viewModel.addAttachmentLabel(it.lastPathSegment ?: "image") }
    }
    val filePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? ->
        uri?.let { viewModel.addAttachmentLabel(it.lastPathSegment ?: "file") }
    }

    FoldableLayout { isFolded, isLandscape ->
        Scaffold(
            topBar = {
                GlassTopBar(
                    title = {
                        Column {
                            Text(
                                "Chat: $agentId",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onBackground,
                            )
                            Text(
                                "Skill: ${state.selectedSkill.label}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    },
                    navigationIcon = {
                        IconButton(
                            onClick = {
                                viewModel.disconnect()
                                onBack()
                            },
                        ) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    },
                )
            },
        ) { padding ->
            if (isLandscape || isFolded) {
                // Two-pane for Fold/Landscape
                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                ) {
                    // Left Pane: Skills and Info (fixed width)
                    Column(
                        modifier = Modifier
                            .width(280.dp)
                            .fillMaxHeight()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            "Skills",
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        CHAT_SKILLS.forEach { skill ->
                            InputChip(
                                selected = state.selectedSkill.id == skill.id,
                                onClick = { viewModel.selectSkill(skill) },
                                label = { Text(skill.label) },
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }

                    // Right Pane: Chat History and Input
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .padding(end = 16.dp, bottom = 16.dp)
                    ) {
                        ChatMessagesArea(state, listState, Modifier.weight(1f))
                        ChatInputArea(
                            inputText = inputText,
                            onInputChange = { inputText = it },
                            state = state,
                            viewModel = viewModel,
                            imagePicker = imagePicker,
                            filePicker = filePicker
                        )
                    }
                }
            } else {
                // Standard/Flip Reachability Column
                ReachabilityColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                ) {
                    // Skill selector
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        CHAT_SKILLS.forEach { skill ->
                            FilterChip(
                                selected = state.selectedSkill.id == skill.id,
                                onClick = { viewModel.selectSkill(skill) },
                                label = { Text(skill.label) },
                                modifier = Modifier.height(40.dp) // Touch friendly
                            )
                        }
                    }

                    ChatMessagesArea(state, listState, Modifier.weight(1f))
                    ChatInputArea(
                        inputText = inputText,
                        onInputChange = { inputText = it },
                        state = state,
                        viewModel = viewModel,
                        imagePicker = imagePicker,
                        filePicker = filePicker
                    )
                }
            }
        }
    }
}

@Composable
private fun ChatMessagesArea(
    state: AgentChatState,
    listState: androidx.compose.foundation.lazy.LazyListState,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (state.messages.isEmpty() && state.pendingAssistantText.isEmpty()) {
                item {
                    EmptyChatIndicator()
                }
            }

            items(state.messages) { msg ->
                ChatBubble(message = msg)
            }

            if (state.pendingAssistantText.isNotEmpty()) {
                item {
                    ChatBubble(
                        message = ChatMessage(
                            id = "pending",
                            role = ChatRole.ASSISTANT,
                            text = state.pendingAssistantText,
                        ),
                        isStreaming = true,
                    )
                }
            }
        }

        state.error?.let { error ->
            GlassCard(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Error, null, tint = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        error,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = { /* viewModel.clearError() */ }) {
                        Icon(Icons.Default.Close, contentDescription = "Dismiss")
                    }
                }
            }
        }
    }
}

@Composable
private fun ChatInputArea(
    inputText: String,
    onInputChange: (String) -> Unit,
    state: AgentChatState,
    viewModel: AgentChatViewModel,
    imagePicker: androidx.activity.result.ActivityResultLauncher<String>,
    filePicker: androidx.activity.result.ActivityResultLauncher<String>
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Attachments row
        if (state.attachmentLabels.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                state.attachmentLabels.forEachIndexed { index, label ->
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Default.AttachFile, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text(
                                label,
                                style = MaterialTheme.typography.labelSmall,
                                maxLines = 1,
                                modifier = Modifier.widthIn(max = 120.dp),
                            )
                            IconButton(
                                onClick = { viewModel.removeAttachmentAt(index) },
                                modifier = Modifier.size(28.dp),
                            ) {
                                Icon(Icons.Default.Close, contentDescription = "Remove", Modifier.size(16.dp))
                            }
                        }
                    }
                }
            }
        }

        // Input row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .navigationBarsPadding(),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            IconButton(
                onClick = { imagePicker.launch("image/*") },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(Icons.Default.Image, contentDescription = "Attach image", modifier = Modifier.size(26.dp))
            }
            IconButton(
                onClick = { filePicker.launch("*/*") },
                modifier = Modifier.size(48.dp)
            ) {
                Icon(Icons.Default.AttachFile, contentDescription = "Attach file", modifier = Modifier.size(26.dp))
            }
            OutlinedTextField(
                value = inputText,
                onValueChange = onInputChange,
                modifier = Modifier
                    .weight(1f)
                    .heightIn(min = 52.dp, max = 150.dp), // Enhanced finger target
                placeholder = { Text("Message…") },
                minLines = 1,
                maxLines = 6,
                shape = RoundedCornerShape(26.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
                )
            )
            FilledIconButton(
                onClick = {
                    viewModel.sendMessage(inputText)
                    onInputChange("")
                },
                enabled = (inputText.isNotBlank() || state.attachmentLabels.isNotEmpty()) && !state.isSending,
                modifier = Modifier.size(52.dp)
            ) {
                if (state.isSending) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                } else {
                    Icon(Icons.Default.Send, contentDescription = "Send", modifier = Modifier.size(24.dp))
                }
            }
        }
    }
}

@Composable
private fun EmptyChatIndicator() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 48.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Default.Message,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.4f),
            )
            Spacer(Modifier.height(20.dp))
            Text(
                "Chat with agent",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "Choose a skill, type a message, or attach a file.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            )
        }
    }
}

@Composable
private fun ChatBubble(
    message: ChatMessage,
    isStreaming: Boolean = false,
) {
    val isUser = message.role == ChatRole.USER
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        if (!isUser) {
            Icon(
                Icons.Default.SmartToy,
                contentDescription = null,
                modifier = Modifier
                    .size(36.dp)
                    .padding(top = 4.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(10.dp))
        }
        Column(
            modifier = Modifier.widthIn(max = 300.dp),
            horizontalAlignment = if (isUser) Alignment.End else Arrangement.Start,
        ) {
            Surface(
                shape = RoundedCornerShape(
                    topStart = 20.dp,
                    topEnd = 20.dp,
                    bottomStart = if (isUser) 20.dp else 4.dp,
                    bottomEnd = if (isUser) 4.dp else 20.dp,
                ),
                color = if (isUser) {
                    MaterialTheme.colorScheme.primaryContainer
                } else {
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
                },
                tonalElevation = 2.dp,
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                ) {
                    message.attachmentLabel?.let { label ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.AttachFile, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
                            Spacer(Modifier.width(4.dp))
                            Text(
                                label,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        Spacer(Modifier.height(6.dp))
                    }
                    Text(
                        message.text,
                        style = MaterialTheme.typography.bodyLarge,
                        color = if (isUser) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                    )
                    if (isStreaming) {
                        Spacer(Modifier.height(6.dp))
                        LinearProgressIndicator(
                            modifier = Modifier.fillMaxWidth().height(3.dp),
                            color = MaterialTheme.colorScheme.primary,
                            trackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)
                        )
                    }
                }
            }
        }
        if (isUser) {
            Spacer(Modifier.width(10.dp))
            Icon(
                Icons.Default.Person,
                contentDescription = null,
                modifier = Modifier
                    .size(36.dp)
                    .padding(top = 4.dp),
                tint = MaterialTheme.colorScheme.tertiary,
            )
        }
    }
}
