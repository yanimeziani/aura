package org.dragun.pegasus.data.repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.dragun.pegasus.data.api.AuthInterceptor
import org.dragun.pegasus.data.store.SessionStore
import javax.inject.Inject
import javax.inject.Singleton

sealed class AgentStreamEvent {
    data class Output(val text: String) : AgentStreamEvent()
    data class Status(val status: String) : AgentStreamEvent()
    data class Error(val message: String) : AgentStreamEvent()
    object Connected : AgentStreamEvent()
    object Disconnected : AgentStreamEvent()
}

@Singleton
class AgentStreamRepository @Inject constructor(
    private val session: SessionStore,
    private val okHttp: OkHttpClient,
    private val authInterceptor: AuthInterceptor,
) {

    fun streamAgentOutput(agentId: String): Flow<AgentStreamEvent> = callbackFlow {
        val apiUrl = session.apiUrl.first() ?: return@callbackFlow

        val request = Request.Builder()
            .url("$apiUrl/agents/$agentId/stream")
            .addHeader("Accept", "text/event-stream")
            .addHeader("Cache-Control", "no-cache")
            .build()

        val client = okHttp.newBuilder()
            .addInterceptor(authInterceptor)
            .build()

        val response = client.newCall(request).execute()

        if (!response.isSuccessful) {
            trySend(AgentStreamEvent.Error("Failed to connect: ${response.code}"))
            close()
            return@callbackFlow
        }

        trySend(AgentStreamEvent.Connected)

        val body = response.body ?: run {
            trySend(AgentStreamEvent.Error("Empty response"))
            close()
            return@callbackFlow
        }

        val buffer = StringBuilder()
        val reader = body.source().buffer().readUtf8()

        reader.use { source ->
            while (true) {
                val line = source.readUtf8Line() ?: break
                buffer.append(line)

                if (line == "") {
                    val data = buffer.toString()
                    if (data.startsWith("data: ")) {
                        val content = data.substring(6).trim()
                        when {
                            content.startsWith("[") || content.startsWith("{") -> {
                                trySend(AgentStreamEvent.Output(content))
                            }
                            content == "DONE" -> {
                                trySend(AgentStreamEvent.Disconnected)
                            }
                            else -> {
                                trySend(AgentStreamEvent.Output(content))
                            }
                        }
                    }
                    buffer.clear()
                }
            }
        }

        awaitClose {
            response.close()
        }
    }

    suspend fun startAgent(agentId: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val apiUrl = session.apiUrl.first() ?: return@withContext Result.failure(Exception("No API URL"))
            val request = Request.Builder()
                .url("$apiUrl/agents/$agentId/start")
                .post(okhttp3.RequestBody.create(null, ByteArray(0)))
                .build()

            val response = okHttp.newBuilder()
                .addInterceptor(authInterceptor)
                .build()
                .newCall(request)
                .execute()

            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                Result.failure(Exception("Failed to start agent: ${response.code}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun stopAgent(agentId: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val apiUrl = session.apiUrl.first() ?: return@withContext Result.failure(Exception("No API URL"))
            val request = Request.Builder()
                .url("$apiUrl/agents/$agentId/stop")
                .post(okhttp3.RequestBody.create(null, ByteArray(0)))
                .build()

            val response = okHttp.newBuilder()
                .addInterceptor(authInterceptor)
                .build()
                .newCall(request)
                .execute()

            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                Result.failure(Exception("Failed to stop agent: ${response.code}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
