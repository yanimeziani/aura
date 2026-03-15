package org.dragun.pegasus.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import org.dragun.pegasus.data.api.CerberusApi
import org.dragun.pegasus.data.security.BiometricHelper
import org.dragun.pegasus.data.store.SessionStore
import org.dragun.pegasus.domain.model.LoginRequest
import javax.crypto.Cipher
import javax.inject.Inject

data class LoginUiState(
    val apiUrl: String = "https://ops.meziani.org",
    val username: String = "",
    val password: String = "",
    val loading: Boolean = false,
    val error: String? = null,
    /** Device has biometric hardware with enrolled fingerprints/faces. */
    val biometricAvailable: Boolean = false,
    /** User previously enrolled biometric unlock for Pegasus. */
    val biometricEnrolled: Boolean = false,
    /** Show enrollment dialog after first password login. */
    val showBiometricEnrollment: Boolean = false,
    /** User chose to see the password form (bypassing biometric). */
    val showPasswordForm: Boolean = false,
)

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val api: CerberusApi,
    private val session: SessionStore,
    val biometricHelper: BiometricHelper,
) : ViewModel() {

    private val _state = MutableStateFlow(LoginUiState())
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    val isLoggedIn: Flow<Boolean> = session.isLoggedIn

    private var _pendingNavigation: (() -> Unit)? = null

    init {
        viewModelScope.launch {
            session.apiUrl.first()?.let { savedUrl ->
                _state.update { it.copy(apiUrl = savedUrl) }
            }
            val biometricAvailable = biometricHelper.canUseBiometric()
            val biometricEnrolled = session.biometricEnabled.first()
            _state.update {
                it.copy(
                    biometricAvailable = biometricAvailable,
                    biometricEnrolled = biometricEnrolled && biometricAvailable,
                )
            }
        }
    }

    fun updateApiUrl(url: String) { _state.update { it.copy(apiUrl = url) } }
    fun updateUsername(u: String) { _state.update { it.copy(username = u) } }
    fun updatePassword(p: String) { _state.update { it.copy(password = p) } }

    /** Switch to the password form (from biometric-first screen). */
    fun showPasswordForm() {
        _state.update { it.copy(showPasswordForm = true, error = null) }
    }

    // ── Password login ──────────────────────────────────────────────────

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

                session.saveServerConfig(apiUrl, sshHost, sshPort, sshUser)
                val resp = api.login(LoginRequest(s.username, s.password))
                if (resp.isSuccessful && resp.body() != null) {
                    val body = resp.body()!!
                    session.saveSession(body.token, body.user, body.role)
                    session.saveServerConfig(apiUrl, sshHost, sshPort, sshUser)
                    _state.update { it.copy(loading = false) }

                    // Offer biometric enrollment if available and not yet set up
                    if (biometricHelper.canUseBiometric() && !session.biometricEnabled.first()) {
                        _pendingNavigation = onSuccess
                        _state.update { it.copy(showBiometricEnrollment = true) }
                    } else {
                        onSuccess()
                    }
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

    // ── Biometric enrolment (after first password login) ────────────────

    /** Create a cipher for encrypting the token during enrollment. */
    fun getEncryptCipher(): Cipher? = biometricHelper.getEncryptCipher()

    /** Called when BiometricPrompt succeeds during enrollment. */
    fun enrollBiometric(cipher: Cipher) {
        viewModelScope.launch {
            try {
                val token = session.token.first()
                    ?: throw IllegalStateException("No token to enroll")
                val user = session.username.first() ?: "unknown"
                val role = session.role.first() ?: "user"
                val enc = biometricHelper.encrypt(cipher, token)
                session.saveBiometricSession(user, role, enc.ciphertext, enc.iv)
                _state.update {
                    it.copy(showBiometricEnrollment = false, biometricEnrolled = true)
                }
            } catch (_: Exception) {
                _state.update { it.copy(showBiometricEnrollment = false) }
            }
            _pendingNavigation?.invoke()
            _pendingNavigation = null
        }
    }

    /** User tapped "Not now" on enrollment. */
    fun skipBiometricEnrollment() {
        _state.update { it.copy(showBiometricEnrollment = false) }
        _pendingNavigation?.invoke()
        _pendingNavigation = null
    }

    // ── Biometric unlock (returning user) ───────────────────────────────

    /** Prepare a decrypt cipher from the stored IV. Null = key invalidated. */
    fun getDecryptCipher(): Cipher? {
        val iv = runBlocking { session.tokenIv.first() } ?: return null
        val cipher = biometricHelper.getDecryptCipher(iv)
        if (cipher == null) {
            // Biometric data changed — key permanently invalidated
            viewModelScope.launch {
                session.clearBiometric()
                biometricHelper.deleteKey()
            }
            _state.update {
                it.copy(biometricEnrolled = false, showPasswordForm = true,
                    error = "Biometric data changed. Please sign in with your password.")
            }
        }
        return cipher
    }

    /** Called when BiometricPrompt succeeds for unlock. */
    fun completeBiometricLogin(cipher: Cipher, onSuccess: () -> Unit) {
        viewModelScope.launch {
            try {
                val encToken = session.encryptedToken.first()
                    ?: throw IllegalStateException("No stored credentials")
                val token = biometricHelper.decrypt(cipher, encToken)
                session.setActiveToken(token)
                onSuccess()
            } catch (_: Exception) {
                // Decryption failed — clear biometric and fall back to password
                session.clearBiometric()
                biometricHelper.deleteKey()
                _state.update {
                    it.copy(
                        biometricEnrolled = false,
                        showPasswordForm = true,
                        error = "Biometric unlock failed. Please sign in with your password.",
                    )
                }
            }
        }
    }

    /** Report a biometric prompt error (hardware failure, lockout, etc.). */
    fun onBiometricError(message: String) {
        _state.update { it.copy(error = message) }
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

    /** Bridge for non-suspend callers that need a synchronous snapshot. */
    @Suppress("FunctionName")
    private fun <T> runBlocking(block: suspend () -> T): T =
        kotlinx.coroutines.runBlocking { block() }
}
