package co.anomaly.pegasus.security

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.*
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Heartbeat Service — Dead Man's Switch
 * 
 * Si ce service s'arrête (téléphone éteint, app killed, etc.),
 * le serveur déclenche le kill switch après timeout.
 * 
 * Architecture:
 * - Foreground service (survit aux app kills)
 * - Heartbeat toutes les 10 secondes
 * - Connexion via TOR
 * - Signature Ed25519 de chaque heartbeat
 */
class HeartbeatService : Service() {
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isRunning = AtomicBoolean(false)
    private lateinit var client: OkHttpClient
    private lateinit var keyPair: Ed25519KeyPair
    
    // Config
    private val heartbeatIntervalMs = 10_000L
    private val serverOnion = "CONDUCTOR_ONION_ADDRESS" // Set at runtime
    
    override fun onCreate() {
        super.onCreate()
        client = createTorClient()
        keyPair = loadOrGenerateKey()
        startForeground(NOTIFICATION_ID, createNotification())
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning.getAndSet(true)) {
            startHeartbeatLoop()
        }
        // Restart if killed
        return START_STICKY
    }
    
    private fun startHeartbeatLoop() {
        scope.launch {
            while (isActive && isRunning.get()) {
                try {
                    sendHeartbeat()
                } catch (e: Exception) {
                    // Log but continue — network issues shouldn't stop heartbeat attempts
                }
                delay(heartbeatIntervalMs)
            }
        }
    }
    
    private suspend fun sendHeartbeat() {
        val timestamp = System.currentTimeMillis()
        val payload = "$timestamp:${keyPair.publicKeyHex}"
        val signature = keyPair.sign(payload.toByteArray())
        
        val body = """
            {
                "timestamp": $timestamp,
                "pubkey": "${keyPair.publicKeyHex}",
                "signature": "${signature.toHex()}"
            }
        """.trimIndent()
        
        val request = Request.Builder()
            .url("http://$serverOnion.onion/heartbeat")
            .post(body.toRequestBody("application/json".toMediaType()))
            .build()
        
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                // Server might be triggering kill switch
                // Or network issue — keep trying
            }
        }
    }
    
    /**
     * Emergency kill — user initiated
     */
    fun triggerEmergency() {
        scope.launch {
            try {
                val request = Request.Builder()
                    .url("http://$serverOnion.onion/emergency")
                    .post("{}".toRequestBody("application/json".toMediaType()))
                    .build()
                
                client.newCall(request).execute().close()
            } finally {
                // Purge local data regardless of network success
                purgeLocalData()
                stopSelf()
            }
        }
    }
    
    private fun purgeLocalData() {
        // Zero sensitive memory
        keyPair.purge()
        
        // Clear app data
        val dataDir = applicationContext.filesDir.parentFile
        dataDir?.deleteRecursively()
        
        // Clear shared preferences
        getSharedPreferences("conductor", MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }
    
    private fun createTorClient(): OkHttpClient {
        val torProxy = java.net.Proxy(
            java.net.Proxy.Type.SOCKS,
            java.net.InetSocketAddress("127.0.0.1", 9050)
        )
        
        return OkHttpClient.Builder()
            .proxy(torProxy)
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }
    
    private fun loadOrGenerateKey(): Ed25519KeyPair {
        // In production: load from secure enclave / Android Keystore
        return Ed25519KeyPair.generate()
    }
    
    private fun createNotification(): Notification {
        val channelId = "heartbeat"
        val channel = NotificationChannel(
            channelId,
            "Security Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            setShowBadge(false)
        }
        
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
        
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Conductor")
            .setContentText("Secure connection active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        isRunning.set(false)
        scope.cancel()
        super.onDestroy()
        // Note: Si le service est killed, le serveur détectera le timeout
        // et déclenchera le kill switch automatiquement
    }
    
    companion object {
        private const val NOTIFICATION_ID = 9999
    }
}

/**
 * Ed25519 Key Pair wrapper
 */
class Ed25519KeyPair private constructor(
    private var secretKey: ByteArray,
    private var publicKey: ByteArray
) {
    val publicKeyHex: String get() = publicKey.toHex()
    
    fun sign(message: ByteArray): ByteArray {
        // Use native Ed25519 signing
        // In production: use conscrypt or native library
        return ByteArray(64) // Placeholder
    }
    
    /**
     * Secure purge — zero memory
     */
    fun purge() {
        secretKey.fill(0)
        publicKey.fill(0)
    }
    
    companion object {
        fun generate(): Ed25519KeyPair {
            // In production: use secure random + Ed25519 lib
            val secret = ByteArray(64)
            val public = ByteArray(32)
            java.security.SecureRandom().nextBytes(secret)
            // Derive public from secret...
            return Ed25519KeyPair(secret, public)
        }
    }
}

fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
