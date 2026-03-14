package org.dragun.pegasus.data.store

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
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
    }

    val token: Flow<String?> = context.dataStore.data.map { it[KEY_TOKEN] }
    val username: Flow<String?> = context.dataStore.data.map { it[KEY_USER] }
    val role: Flow<String?> = context.dataStore.data.map { it[KEY_ROLE] }
    val apiUrl: Flow<String?> = context.dataStore.data.map { it[KEY_API_URL] }
    val sshHost: Flow<String?> = context.dataStore.data.map { it[KEY_SSH_HOST] }
    val sshPort: Flow<String?> = context.dataStore.data.map { it[KEY_SSH_PORT] }
    val sshUser: Flow<String?> = context.dataStore.data.map { it[KEY_SSH_USER] }

    val isLoggedIn: Flow<Boolean> = token.map { !it.isNullOrBlank() }

    suspend fun saveSession(token: String, user: String, role: String) {
        context.dataStore.edit {
            it[KEY_TOKEN] = token
            it[KEY_USER] = user
            it[KEY_ROLE] = role
        }
    }

    suspend fun saveServerConfig(apiUrl: String, sshHost: String, sshPort: Int, sshUser: String) {
        context.dataStore.edit {
            it[KEY_API_URL] = apiUrl
            it[KEY_SSH_HOST] = sshHost
            it[KEY_SSH_PORT] = sshPort.toString()
            it[KEY_SSH_USER] = sshUser
        }
    }

    suspend fun clear() {
        context.dataStore.edit { it.clear() }
    }
}
