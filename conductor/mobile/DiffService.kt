package co.anomaly.pegasus.diff

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

@Serializable
data class ApiChangeRequest(
    val id: String,
    val title: String,
    val description: String,
    val agentId: String,
    val files: List<ApiFileDiff>,
    val status: String,
    val createdAt: Long
)

@Serializable
data class ApiFileDiff(
    val path: String,
    val status: String,
    val additions: Int,
    val deletions: Int,
    val hunks: List<ApiHunk>
)

@Serializable
data class ApiHunk(
    val oldStart: Int,
    val newStart: Int,
    val lines: List<ApiLine>
)

@Serializable
data class ApiLine(
    val kind: String,
    val content: String
)

class DiffService(
    private val context: Context,
    private val baseUrl: String = "http://89.116.170.202:8080"
) {
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    private val _pendingChanges = MutableStateFlow<List<ApiChangeRequest>>(emptyList())
    val pendingChanges: StateFlow<List<ApiChangeRequest>> = _pendingChanges.asStateFlow()

    init {
        createNotificationChannel()
        startPolling()
    }

    private fun startPolling() {
        scope.launch {
            while (isActive) {
                try {
                    fetchPending()
                } catch (e: Exception) {
                    // Log error, continue polling
                }
                delay(5000) // Poll every 5 seconds
            }
        }
    }

    suspend fun fetchPending() {
        val request = Request.Builder()
            .url("$baseUrl/pending")
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            if (response.isSuccessful) {
                val body = response.body?.string() ?: return
                val changes = json.decodeFromString<List<ApiChangeRequest>>(body)
                
                val newChanges = changes.filter { new ->
                    _pendingChanges.value.none { it.id == new.id }
                }
                
                if (newChanges.isNotEmpty()) {
                    showNotification(newChanges.size)
                }
                
                _pendingChanges.value = changes
            }
        }
    }

    suspend fun approve(id: String): Boolean {
        val request = Request.Builder()
            .url("$baseUrl/approve/$id")
            .post("".toRequestBody("application/json".toMediaType()))
            .build()

        return try {
            client.newCall(request).execute().use { it.isSuccessful }
        } catch (e: IOException) {
            false
        }
    }

    suspend fun reject(id: String): Boolean {
        val request = Request.Builder()
            .url("$baseUrl/reject/$id")
            .post("".toRequestBody("application/json".toMediaType()))
            .build()

        return try {
            client.newCall(request).execute().use { it.isSuccessful }
        } catch (e: IOException) {
            false
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Code Reviews",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notifications for pending code reviews"
        }
        
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun showNotification(count: Int) {
        val intent = Intent(context, DiffViewerActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("$count pending review${if (count > 1) "s" else ""}")
            .setContentText("Tap to review agent changes")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun destroy() {
        scope.cancel()
    }

    companion object {
        private const val CHANNEL_ID = "diff_reviews"
        private const val NOTIFICATION_ID = 1001
    }
}
