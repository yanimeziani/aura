package org.dragun.pegasus.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.api.CerberusApi
import org.dragun.pegasus.data.repository.AgentStreamEvent
import org.dragun.pegasus.data.repository.AgentStreamRepository
import org.dragun.pegasus.domain.model.ChatMessage
import org.dragun.pegasus.domain.model.ChatRole
import org.dragun.pegasus.domain.model.ChatSkill
import org.dragun.pegasus.domain.model.TaskSubmit
import java.util.UUID
import javax.inject.Inject

val CHAT_SKILLS = listOf(
    ChatSkill("general", "General", "normal"),
    ChatSkill("task", "Task", "high"),
    ChatSkill("code", "Code", "normal"),
    ChatSkill("research", "Research", "normal"),
)

data class AgentChatState(
    val agentId: String = "",
    val messages: List<ChatMessage> = emptyList(),
    val pendingAssistantText: String = "",
    val isStreaming: Boolean = false,
    val isSending: Boolean = false,
    val selectedSkill: ChatSkill = CHAT_SKILLS.first(),
    val attachmentLabels: List<String> = emptyList(),
    val error: String? = null,
)

@HiltViewModel
class AgentChatViewModel @Inject constructor(
    private val api: CerberusApi,
    private val streamRepo: AgentStreamRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(AgentChatState())
    val state: StateFlow<AgentChatState> = _state.asStateFlow()

    private var streamJob: Job? = null

    fun setAgent(agentId: String) {
        _state.update { it.copy(agentId = agentId, error = null) }
    }

    fun selectSkill(skill: ChatSkill) {
        _state.update { it.copy(selectedSkill = skill) }
    }

    fun addAttachmentLabel(label: String) {
        _state.update { it.copy(attachmentLabels = it.attachmentLabels + label) }
    }

    fun removeAttachmentAt(index: Int) {
        _state.update { it.copy(attachmentLabels = it.attachmentLabels.filterIndexed { i, _ -> i != index }) }
    }

    fun clearAttachments() {
        _state.update { it.copy(attachmentLabels = emptyList()) }
    }

    fun sendMessage(text: String) {
        val trimmed = text.trim()
        val attachments = _state.value.attachmentLabels
        if (trimmed.isBlank() && attachments.isEmpty()) return

        val agentId = _state.value.agentId
        if (agentId.isBlank()) return

        val fullDescription = buildString {
            append(trimmed)
            if (attachments.isNotEmpty()) {
                append("\n[Attachments: ")
                append(attachments.joinToString(", "))
                append("]")
            }
        }

        val userMessage = ChatMessage(
            id = UUID.randomUUID().toString(),
            role = ChatRole.USER,
            text = trimmed,
            attachmentLabel = attachments.takeIf { it.isNotEmpty() }?.joinToString(", "),
        )
        _state.update {
            it.copy(
                messages = it.messages + userMessage,
                attachmentLabels = emptyList(),
                isSending = true,
                error = null,
            )
        }

        streamJob?.cancel()
        streamJob = viewModelScope.launch {
            try {
                val submitResult = api.submitTask(
                    TaskSubmit(
                        agent_id = agentId,
                        description = fullDescription,
                        priority = _state.value.selectedSkill.priority,
                    )
                )
                if (!submitResult.isSuccessful) {
                    _state.update {
                        it.copy(
                            isSending = false,
                            error = "Send failed: ${submitResult.code()}",
                        )
                    }
                    return@launch
                }
                _state.update { it.copy(isSending = false, isStreaming = true, pendingAssistantText = "") }

                streamRepo.streamAgentOutput(agentId).collect { event ->
                    when (event) {
                        is AgentStreamEvent.Output -> {
                            _state.update {
                                it.copy(pendingAssistantText = it.pendingAssistantText + event.text)
                            }
                        }
                        is AgentStreamEvent.Status -> {
                            // Show status updates as inline markers
                            val marker = "[${event.status}]\n"
                            _state.update {
                                it.copy(pendingAssistantText = it.pendingAssistantText + marker)
                            }
                        }
                        is AgentStreamEvent.Connected -> {
                            // Show a brief connected indicator in pending text
                            _state.update {
                                it.copy(pendingAssistantText = it.pendingAssistantText + "[Connected to stream]\n")
                            }
                        }
                        is AgentStreamEvent.Error -> {
                            _state.update {
                                it.copy(
                                    isStreaming = false,
                                    pendingAssistantText = "",
                                    error = event.message,
                                )
                            }
                        }
                        is AgentStreamEvent.Disconnected -> {
                            val pending = _state.value.pendingAssistantText
                            _state.update { state ->
                                val newMsg = if (pending.isNotBlank()) {
                                    ChatMessage(
                                        id = UUID.randomUUID().toString(),
                                        role = ChatRole.ASSISTANT,
                                        text = pending.trim(),
                                    )
                                } else null
                                state.copy(
                                    isStreaming = false,
                                    pendingAssistantText = "",
                                    messages = state.messages + listOfNotNull(newMsg),
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isSending = false,
                        isStreaming = false,
                        error = e.message ?: "Unknown error",
                    )
                }
            }
        }
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }

    fun disconnect() {
        streamJob?.cancel()
        _state.update { it.copy(isStreaming = false, pendingAssistantText = "") }
    }

    override fun onCleared() {
        super.onCleared()
        streamJob?.cancel()
    }
}
