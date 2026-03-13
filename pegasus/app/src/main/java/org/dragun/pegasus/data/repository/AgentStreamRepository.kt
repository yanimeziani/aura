package org.dragun.pegasus.data.repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
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

    companion object {
        /** Auto-disconnect after this many ms of only heartbeats following real output. */
        private const val IDLE_TIMEOUT_MS = 10_000L
    }

    fun streamAgentOutput(agentId: String): Flow<AgentStreamEvent> = callbackFlow {
        val apiUrl = session.apiUrl.first()
        
        if (apiUrl.isNullOrBlank()) {
            trySend(AgentStreamEvent.Error("API URL not configured"))
            close()
            return@callbackFlow
        }

        var response: Response? = null

        val streamJob: Job = launch(Dispatchers.IO) {
            try {
                val request = Request.Builder()
                    .url("$apiUrl/agents/$agentId/stream")
                    .addHeader("Accept", "text/event-stream")
                    .addHeader("Cache-Control", "no-cache")
                    .build()

                val client = okHttp.newBuilder()
                    .addInterceptor(authInterceptor)
                    .build()

                response = client.newCall(request).execute()

                if (!response!!.isSuccessful) {
                    val errorBody = response!!.body?.string()?.take(300)
                    val suffix = if (errorBody.isNullOrBlank()) "" else " - $errorBody"
                    trySend(AgentStreamEvent.Error("Failed to connect: ${response!!.code}$suffix"))
                    close()
                    return@launch
                }

                trySend(AgentStreamEvent.Connected)

                val body = response!!.body ?: run {
                    trySend(AgentStreamEvent.Error("Empty response"))
                    close()
                    return@launch
                }

                val source = body.source()
                val buffer = StringBuilder()
                var lastRealEventTime = System.currentTimeMillis()
                var hasReceivedOutput = false

                while (true) {
                    val line = source.readUtf8Line() ?: break

                    if (line.isEmpty()) {
                        val data = buffer.toString()
                        if (data.startsWith("data: ")) {
                            val content = data.substring(6).trim()
                            when {
                                content == "DONE" -> {
                                    trySend(AgentStreamEvent.Disconnected)
                                }
                                content.isNotEmpty() -> {
                                    val parsed = parseSsePayload(content)
                                    when {
                                        parsed == null -> {
                                            lastRealEventTime = System.currentTimeMillis()
                                            hasReceivedOutput = true
                                            trySend(AgentStreamEvent.Output(content))
                                        }
                                        parsed.kind == "heartbeat" -> {
                                            // Ignore noisy heartbeat events.
                                            // If we got real output and heartbeats have been idle
                                            // for IDLE_TIMEOUT_MS, treat stream as complete.
                                            if (hasReceivedOutput &&
                                                System.currentTimeMillis() - lastRealEventTime > IDLE_TIMEOUT_MS
                                            ) {
                                                trySend(AgentStreamEvent.Disconnected)
                                                break
                                            }
                                        }
                                        parsed.kind.startsWith("agent.") -> {
                                            lastRealEventTime = System.currentTimeMillis()
                                            trySend(AgentStreamEvent.Status(parsed.summary ?: parsed.kind))
                                        }
                                        parsed.kind.startsWith("task.") -> {
                                            lastRealEventTime = System.currentTimeMillis()
                                            trySend(AgentStreamEvent.Status(parsed.summary ?: parsed.kind))
                                        }
                                        else -> {
                                            lastRealEventTime = System.currentTimeMillis()
                                            hasReceivedOutput = true
                                            trySend(AgentStreamEvent.Output(parsed.summary ?: content))
                                        }
                                    }
                                }
                            }
                        }
                        buffer.clear()
                    } else {
                        if (line.startsWith("data: ")) {
                            if (buffer.isNotEmpty()) buffer.append('\n')
                            buffer.append(line)
                        }
                    }
                }
            } catch (e: Exception) {
                val detail = e.message ?: e::class.java.simpleName
                trySend(AgentStreamEvent.Error("Stream error: $detail"))
            } finally {
                response?.close()
            }
        }

        awaitClose {
            streamJob.cancel()
            response?.close()
        }
    }

    suspend fun startAgent(agentId: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val apiUrl = session.apiUrl.first() ?: return@withContext Result.failure(Exception("No API URL"))
            val request = Request.Builder()
                .url("$apiUrl/agents/$agentId/start")
                .post(ByteArray(0).toRequestBody(null))
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
                .post(ByteArray(0).toRequestBody(null))
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

    private data class ParsedEvent(val kind: String, val summary: String?)

    private fun parseSsePayload(raw: String): ParsedEvent? {
        return try {
            val json = JSONObject(raw)
            ParsedEvent(
                kind = json.optString("kind", "message"),
                summary = json.optString("summary").takeIf { it.isNotBlank() }
                    ?: json.optString("status").takeIf { it.isNotBlank() }
            )
        } catch (_: Exception) {
            null
        }
    }
}
