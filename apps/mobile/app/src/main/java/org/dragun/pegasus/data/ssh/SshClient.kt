package org.dragun.pegasus.data.ssh

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import net.schmizz.sshj.SSHClient
import net.schmizz.sshj.common.IOUtils
import net.schmizz.sshj.transport.verification.PromiscuousVerifier
import java.io.Closeable
import java.util.concurrent.TimeUnit
import javax.inject.Inject

data class SshResult(val exitCode: Int, val stdout: String, val stderr: String) {
    val success get() = exitCode == 0
    val output get() = stdout.ifBlank { stderr }
}

class SshClientWrapper @Inject constructor() : Closeable {

    private var client: SSHClient? = null

    suspend fun connect(host: String, port: Int, user: String, password: String? = null, keyPath: String? = null) {
        withContext(Dispatchers.IO) {
            val ssh = SSHClient()
            ssh.addHostKeyVerifier(PromiscuousVerifier())
            ssh.connect(host, port)

            when {
                keyPath != null -> ssh.authPublickey(user, keyPath)
                password != null -> ssh.authPassword(user, password)
                else -> ssh.authPublickey(user)
            }
            client = ssh
        }
    }

    suspend fun exec(command: String, timeoutSec: Long = 30): SshResult = withContext(Dispatchers.IO) {
        val ssh = client ?: throw IllegalStateException("Not connected")
        val session = ssh.startSession()
        try {
            val cmd = session.exec(command)
            cmd.join(timeoutSec, TimeUnit.SECONDS)
            val stdout = String(IOUtils.readFully(cmd.inputStream).toByteArray(), Charsets.UTF_8)
            val stderr = String(IOUtils.readFully(cmd.errorStream).toByteArray(), Charsets.UTF_8)
            SshResult(cmd.exitStatus ?: -1, stdout.trim(), stderr.trim())
        } finally {
            session.close()
        }
    }

    val isConnected: Boolean get() = client?.isConnected == true

    override fun close() {
        client?.disconnect()
        client = null
    }
}
