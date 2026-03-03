package org.dragun.pegasus.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.api.OpenClawApi
import org.dragun.pegasus.data.store.SessionStore
import org.dragun.pegasus.domain.model.*
import javax.inject.Inject

data class DashboardState(
    val health: HealthStatus? = null,
    val agents: Map<String, AgentInfo> = emptyMap(),
    val costs: CostStatus? = null,
    val hitlCount: Int = 0,
    val panicActive: Boolean = false,
    val loading: Boolean = true,
    val error: String? = null,
    val username: String = "",
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val api: OpenClawApi,
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
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                val healthResp = api.health()
                val agentsResp = api.agents()
                val costsResp = api.costStatus()
                val hitlResp = api.hitlQueue()

                _state.update {
                    it.copy(
                        health = healthResp.body(),
                        agents = agentsResp.body() ?: emptyMap(),
                        costs = costsResp.body(),
                        hitlCount = hitlResp.body()?.count ?: 0,
                        panicActive = healthResp.body()?.panic == true,
                        loading = false,
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(loading = false, error = e.message) }
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
