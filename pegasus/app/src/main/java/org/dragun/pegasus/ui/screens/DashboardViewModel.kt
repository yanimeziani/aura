package org.dragun.pegasus.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.api.CerberusApi
import org.dragun.pegasus.data.store.SessionStore
import org.dragun.pegasus.domain.model.AgentInfo
import org.dragun.pegasus.domain.model.CostStatus
import org.dragun.pegasus.domain.model.HealthStatus
import org.dragun.pegasus.domain.model.TaskSubmit
import javax.inject.Inject

data class DashboardState(
    val health: HealthStatus? = null,
    val agents: Map<String, AgentInfo> = emptyMap(),
    val primaryAgentId: String? = null,
    val costs: CostStatus? = null,
    val hitlCount: Int = 0,
    val panicActive: Boolean = false,
    val loading: Boolean = false,
    val error: String? = null,
    val username: String = "",
    val messageAgentId: String? = null,
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val api: CerberusApi,
    private val session: SessionStore,
) : ViewModel() {

    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            session.username.collect { u -> _state.update { it.copy(username = u ?: "") } }
        }
        refresh()
        startAutoRefresh()
    }

    fun refresh() {
        if (_state.value.loading) return
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                coroutineScope {
                    val healthDeferred = async { api.health() }
                    val agentsDeferred = async { api.agents() }
                    val primaryDeferred = async { api.primaryAgent() }
                    val costsDeferred = async { api.costStatus() }
                    val hitlDeferred = async { api.hitlQueue() }
                    awaitAll(healthDeferred, agentsDeferred, primaryDeferred, costsDeferred, hitlDeferred)
                    val healthResp = healthDeferred.getCompleted()
                    val agentsResp = agentsDeferred.getCompleted()
                    val primaryResp = primaryDeferred.getCompleted()
                    val costsResp = costsDeferred.getCompleted()
                    val hitlResp = hitlDeferred.getCompleted()

                    _state.update {
                        it.copy(
                            health = healthResp.body(),
                            agents = agentsResp.body() ?: emptyMap(),
                            primaryAgentId = primaryResp.body()?.primary_agent_id,
                            costs = costsResp.body(),
                            hitlCount = hitlResp.body()?.count ?: 0,
                            panicActive = healthResp.body()?.panic == true,
                        )
                    }
                }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message) }
            } finally {
                _state.update { it.copy(loading = false) }
            }
        }
    }

    fun togglePanic() {
        viewModelScope.launch {
            try {
                if (_state.value.panicActive) api.clearPanic()
                else api.triggerPanic("pegasus-dashboard")
                refresh()
            } catch (e: Exception) {
                _state.update { it.copy(error = "Panic toggle failed: ${e.message}") }
            }
        }
    }

    fun startAgent(agentId: String) {
        viewModelScope.launch {
            try {
                api.startAgent(agentId)
                refresh()
            } catch (e: Exception) {
                _state.update { it.copy(error = "Failed to start agent: ${e.message}") }
            }
        }
    }

    fun stopAgent(agentId: String) {
        viewModelScope.launch {
            try {
                api.stopAgent(agentId)
                refresh()
            } catch (e: Exception) {
                _state.update { it.copy(error = "Failed to stop agent: ${e.message}") }
            }
        }
    }

    fun openMessageAgent(agentId: String) {
        _state.update { it.copy(messageAgentId = agentId) }
    }

    fun closeMessageAgent() {
        _state.update { it.copy(messageAgentId = null) }
    }

    fun submitTask(agentId: String, description: String, onDone: () -> Unit) {
        viewModelScope.launch {
            try {
                api.submitTask(TaskSubmit(agent_id = agentId, description = description))
                _state.update { it.copy(messageAgentId = null) }
                refresh()
                onDone()
            } catch (e: Exception) {
                _state.update { it.copy(error = "Send failed: ${e.message}") }
            }
        }
    }

    fun logout(onDone: () -> Unit) {
        viewModelScope.launch {
            try { api.logout() } catch (_: Exception) {}
            session.clear()
            onDone()
        }
    }

    private fun startAutoRefresh() {
        viewModelScope.launch {
            while (true) {
                delay(15_000)
                try { refresh() } catch (_: Exception) {}
            }
        }
    }
}
