package org.dragun.pegasus.data.shell

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

sealed class ShellOutput {
    data class Stdout(val text: String) : ShellOutput()
    data class Stderr(val text: String) : ShellOutput()
}

@Singleton
class PegasusShell @Inject constructor() {

    private val _output = MutableSharedFlow<ShellOutput>(extraBufferCapacity = 64)
    val output = _output.asSharedFlow()

    private var initialized = false

    fun initialize() {
        if (initialized) return
        try {
            System.loadLibrary("pegasus_shell")
            nativeInit()
            initialized = true
        } catch (e: UnsatisfiedLinkError) {
            // Native library not available, use fallback
        }
    }

    suspend fun execute(command: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            if (initialized) {
                val result = nativeExecute(command)
                Result.success(result ?: "")
            } else {
                executeFallback(command)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private suspend fun executeFallback(command: String): Result<String> = withContext(Dispatchers.IO) {
        val parts = command.trim().split(" ")
        val output = when (parts[0]) {
            "help" -> buildString {
                appendLine("Pegasus Shell (Fallback Mode)")
                appendLine()
                appendLine("Built-in commands:")
                appendLine("  echo <text>    - Print text")
                appendLine("  date           - Show current timestamp")
                appendLine("  whoami         - Show current user")
                appendLine("  pwd            - Show working directory")
                appendLine("  agents         - Agent management")
                appendLine("  help           - Show this help")
            }
            "date" -> System.currentTimeMillis().toString()
            "whoami" -> "pegasus"
            "pwd" -> "/data/data/org.dragun.pegasus"
            "echo" -> parts.drop(1).joinToString(" ")
            "agents" -> buildString {
                appendLine("Agent Management")
                appendLine("Use the Dashboard to view and manage agents")
                appendLine("Commands: agents list, agents start <id>, agents stop <id>")
            }
            else -> "Command not found: ${parts[0]}. Type 'help' for available commands."
        }
        Result.success(output)
    }

    fun cleanup() {
        if (initialized) {
            try {
                nativeCleanup()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    private external fun nativeInit(): String
    private external fun nativeExecute(command: String): String?
    private external fun nativeCleanup()
}
