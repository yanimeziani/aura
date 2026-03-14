package org.dragun.pegasus.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.api.CerberusApi
import org.dragun.pegasus.data.store.SessionStore
import org.dragun.pegasus.domain.model.LoginRequest
import javax.inject.Inject

data class LoginUiState(
    val apiUrl: String = "https://ops.meziani.org",
    val username: String = "",
    val password: String = "",
    val loading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val api: CerberusApi,
    private val session: SessionStore,
) : ViewModel() {

    private val _state = MutableStateFlow(LoginUiState())
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    val isLoggedIn: Flow<Boolean> = session.isLoggedIn

    init {
        viewModelScope.launch {
            session.apiUrl.first()?.let { savedUrl ->
                _state.update { it.copy(apiUrl = savedUrl) }
            }
        }
    }

    fun updateApiUrl(url: String) { _state.update { it.copy(apiUrl = url) } }
    fun updateUsername(u: String) { _state.update { it.copy(username = u) } }
    fun updatePassword(p: String) { _state.update { it.copy(password = p) } }

    fun login(onSuccess: () -> Unit) {
        val s = _state.value
        val apiUrl = normalizeApiUrl(s.apiUrl)
        if (apiUrl.isBlank() || s.username.isBlank() || s.password.isBlank()) {
            _state.update { it.copy(error = "Server URL, username, and password required") }
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            try {
                val sshHost = session.sshHost.first().orEmpty()
                val sshPort = session.sshPort.first()?.toIntOrNull() ?: 22
                val sshUser = session.sshUser.first().orEmpty().ifBlank { "root" }

                // Persist target API URL before the request so networking uses the selected server.
                session.saveServerConfig(apiUrl, sshHost, sshPort, sshUser)
                val resp = api.login(LoginRequest(s.username, s.password))
                if (resp.isSuccessful && resp.body() != null) {
                    val body = resp.body()!!
                    session.saveSession(body.token, body.user, body.role)
                    session.saveServerConfig(apiUrl, sshHost, sshPort, sshUser)
                    _state.update { it.copy(loading = false) }
                    onSuccess()
                } else {
                    _state.update {
                        it.copy(loading = false, error = "Login failed: ${resp.code()}")
                    }
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(loading = false, error = e.message ?: "Connection error")
                }
            }
        }
    }

    private fun normalizeApiUrl(url: String): String {
        val trimmed = url.trim().trimEnd('/')
        if (trimmed.isBlank()) return ""
        return if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            trimmed
        } else {
            "https://$trimmed"
        }
    }
}
