package org.dragun.pegasus.domain.model

data class LoginRequest(val username: String, val password: String)

data class TokenResponse(
    val token: String,
    val user: String,
    val role: String,
    val expires_at: String? = null,
)

data class HealthStatus(
    val status: String,
    val panic: Boolean,
    val uptime_s: Double,
)

data class AgentInfo(
    val last_seen: String?,
    val current_task: String?,
    val status: String?,
)

data class PrimaryAgentResponse(val primary_agent_id: String?)

data class AgentControlResult(
    val success: Boolean,
    val agent_id: String,
    val action: String,
    val message: String?,
)

data class HitlItem(
    val task_id: String,
    val agent_id: String,
    val action: String,
    val blast_radius: String,
    val reversible: Boolean,
    val diff_preview: String? = null,
    val risk_note: String? = null,
    val risk_label: String? = null,
    val submitted_at: String? = null,
    val status: String? = null,
)

data class HitlQueue(
    val status: String,
    val count: Int,
    val items: List<HitlItem>,
)

data class CostEntry(
    val spent_usd: Double,
    val cap_usd: Double,
    val pct: Double,
    val status: String,
)

data class CostStatus(
    val date: String,
    val panic_active: Boolean,
    val agents: Map<String, CostEntry>,
)

data class TaskSubmit(
    val agent_id: String,
    val description: String,
    val priority: String = "normal",
)

data class TaskResult(
    val task_id: String,
    val agent_id: String,
    val status: String,
)

data class PanicStatus(val panic: Boolean, val reason: String? = null)

data class ServerConfig(
    val apiUrl: String,
    val sshHost: String = "",
    val sshPort: Int = 22,
    val sshUser: String = "root",
)

/** Chat message for agent chat UI. */
data class ChatMessage(
    val id: String,
    val role: ChatRole,
    val text: String,
    val attachmentLabel: String? = null,
)

enum class ChatRole { USER, ASSISTANT }

/** Skill / task type for agent chat. */
data class ChatSkill(
    val id: String,
    val label: String,
    val priority: String,
)
