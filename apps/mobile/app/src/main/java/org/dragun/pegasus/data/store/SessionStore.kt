package org.dragun.pegasus.data.store

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore(name = "pegasus_session")

@Singleton
class SessionStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        private val KEY_TOKEN = stringPreferencesKey("api_token")
        private val KEY_USER = stringPreferencesKey("username")
        private val KEY_ROLE = stringPreferencesKey("role")
        private val KEY_API_URL = stringPreferencesKey("api_url")
        private val KEY_SSH_HOST = stringPreferencesKey("ssh_host")
        private val KEY_SSH_PORT = stringPreferencesKey("ssh_port")
        private val KEY_SSH_USER = stringPreferencesKey("ssh_user")
        // Biometric-encrypted credentials
        private val KEY_BIOMETRIC_ENABLED = stringPreferencesKey("biometric_enabled")
        private val KEY_ENCRYPTED_TOKEN = stringPreferencesKey("encrypted_token")
        private val KEY_TOKEN_IV = stringPreferencesKey("token_iv")
    }

    /**
     * In-memory token set after biometric unlock.
     * Cleared on process death — forces re-authentication on cold start.
     */
    private val _activeToken = MutableStateFlow<String?>(null)
    private val _diskToken: Flow<String?> = context.dataStore.data.map { it[KEY_TOKEN] }

    /** Effective token: biometric-unlocked (memory) takes priority over disk. */
    val token: Flow<String?> = _activeToken.combine(_diskToken) { mem, disk -> mem ?: disk }

    val username: Flow<String?> = context.dataStore.data.map { it[KEY_USER] }
    val role: Flow<String?> = context.dataStore.data.map { it[KEY_ROLE] }
    val apiUrl: Flow<String?> = context.dataStore.data.map { it[KEY_API_URL] }
    val sshHost: Flow<String?> = context.dataStore.data.map { it[KEY_SSH_HOST] }
    val sshPort: Flow<String?> = context.dataStore.data.map { it[KEY_SSH_PORT] }
    val sshUser: Flow<String?> = context.dataStore.data.map { it[KEY_SSH_USER] }

    val biometricEnabled: Flow<Boolean> =
        context.dataStore.data.map { it[KEY_BIOMETRIC_ENABLED] == "true" }
    val encryptedToken: Flow<String?> = context.dataStore.data.map { it[KEY_ENCRYPTED_TOKEN] }
    val tokenIv: Flow<String?> = context.dataStore.data.map { it[KEY_TOKEN_IV] }

    val isLoggedIn: Flow<Boolean> = token.map { !it.isNullOrBlank() }

    /** Standard password-based session. Token stored in plain text (Android FBE protects at rest). */
    suspend fun saveSession(token: String, user: String, role: String) {
        context.dataStore.edit {
            it[KEY_TOKEN] = token
            it[KEY_USER] = user
            it[KEY_ROLE] = role
        }
    }

    /**
     * Biometric-enrolled session. Plain token is removed from disk;
     * only the encrypted version persists. On next cold start the user
     * must authenticate biometrically to decrypt it.
     */
    suspend fun saveBiometricSession(user: String, role: String, encToken: String, iv: String) {
        context.dataStore.edit {
            it.remove(KEY_TOKEN)
            it[KEY_USER] = user
            it[KEY_ROLE] = role
            it[KEY_BIOMETRIC_ENABLED] = "true"
            it[KEY_ENCRYPTED_TOKEN] = encToken
            it[KEY_TOKEN_IV] = iv
        }
    }

    /** Set the in-memory token after a successful biometric unlock. */
    fun setActiveToken(token: String) {
        _activeToken.value = token
    }

    suspend fun saveServerConfig(apiUrl: String, sshHost: String, sshPort: Int, sshUser: String) {
        context.dataStore.edit {
            it[KEY_API_URL] = apiUrl
            it[KEY_SSH_HOST] = sshHost
            it[KEY_SSH_PORT] = sshPort.toString()
            it[KEY_SSH_USER] = sshUser
        }
    }

    suspend fun clearBiometric() {
        context.dataStore.edit {
            it.remove(KEY_BIOMETRIC_ENABLED)
            it.remove(KEY_ENCRYPTED_TOKEN)
            it.remove(KEY_TOKEN_IV)
        }
    }

    suspend fun clear() {
        _activeToken.value = null
        context.dataStore.edit { it.clear() }
    }
}
