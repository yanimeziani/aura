package co.anomaly.pegasus.diff

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

// Nord colors
object Nord {
    val bg = Color(0xFF2E3440)
    val bgLight = Color(0xFF3B4252)
    val bgLighter = Color(0xFF434C5E)
    val text = Color(0xFFD8DEE9)
    val textDim = Color(0xFF4C566A)
    val accent = Color(0xFF88C0D0)
    val green = Color(0xFFA3BE8C)
    val red = Color(0xFFBF616A)
    val yellow = Color(0xFFEBCB8B)
}

data class DiffLine(
    val kind: LineKind,
    val content: String,
    val lineNumber: Int?
)

enum class LineKind { Context, Addition, Deletion }

data class FileDiff(
    val path: String,
    val additions: Int,
    val deletions: Int,
    val lines: List<DiffLine>
)

data class ChangeRequest(
    val id: String,
    val title: String,
    val description: String,
    val agentId: String,
    val files: List<FileDiff>,
    val timestamp: Long
)

class DiffViewerActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            DiffViewerApp()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun DiffViewerApp() {
    var currentIndex by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()
    
    // Sample data - would come from API
    val changes = remember {
        listOf(
            ChangeRequest(
                id = "cr-001",
                title = "Add user authentication",
                description = "Implement JWT-based auth flow",
                agentId = "coder-agent",
                files = listOf(
                    FileDiff(
                        path = "src/auth/login.zig",
                        additions = 45,
                        deletions = 3,
                        lines = listOf(
                            DiffLine(LineKind.Context, "const std = @import(\"std\");", 1),
                            DiffLine(LineKind.Addition, "const jwt = @import(\"jwt.zig\");", null),
                            DiffLine(LineKind.Addition, "", null),
                            DiffLine(LineKind.Deletion, "// TODO: implement auth", 3),
                            DiffLine(LineKind.Addition, "pub fn authenticate(token: []const u8) !User {", null),
                            DiffLine(LineKind.Addition, "    return jwt.verify(token);", null),
                            DiffLine(LineKind.Addition, "}", null),
                        )
                    )
                ),
                timestamp = System.currentTimeMillis()
            )
        )
    }

    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Nord.bg,
            surface = Nord.bgLight,
            primary = Nord.accent,
            onBackground = Nord.text,
            onSurface = Nord.text
        )
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Review Changes") },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Nord.bg
                    ),
                    actions = {
                        Text(
                            "${currentIndex + 1}/${changes.size}",
                            color = Nord.textDim,
                            modifier = Modifier.padding(end = 16.dp)
                        )
                    }
                )
            },
            bottomBar = {
                SwipeActionBar(
                    onApprove = {
                        scope.launch {
                            // API call to approve
                            if (currentIndex < changes.size - 1) currentIndex++
                        }
                    },
                    onReject = {
                        scope.launch {
                            // API call to reject
                            if (currentIndex < changes.size - 1) currentIndex++
                        }
                    }
                )
            }
        ) { padding ->
            if (changes.isNotEmpty()) {
                ChangeRequestView(
                    cr = changes[currentIndex],
                    modifier = Modifier.padding(padding)
                )
            } else {
                EmptyState(Modifier.padding(padding))
            }
        }
    }
}

@Composable
fun ChangeRequestView(cr: ChangeRequest, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(Nord.bg),
        contentPadding = PaddingValues(16.dp)
    ) {
        // Header
        item {
            Column(modifier = Modifier.padding(bottom = 16.dp)) {
                Text(
                    cr.title,
                    fontSize = 20.sp,
                    color = Nord.text
                )
                Text(
                    "by ${cr.agentId}",
                    fontSize = 14.sp,
                    color = Nord.textDim
                )
                if (cr.description.isNotEmpty()) {
                    Text(
                        cr.description,
                        fontSize = 14.sp,
                        color = Nord.text.copy(alpha = 0.8f),
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
        }

        // Files
        cr.files.forEach { file ->
            item {
                FileHeader(file)
            }
            items(file.lines) { line ->
                DiffLineView(line)
            }
            item {
                Spacer(Modifier.height(16.dp))
            }
        }
    }
}

@Composable
fun FileHeader(file: FileDiff) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Nord.bgLighter, RoundedCornerShape(topStart = 8.dp, topEnd = 8.dp))
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            file.path,
            fontFamily = FontFamily.Monospace,
            fontSize = 13.sp,
            color = Nord.accent,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Row {
            Text(
                "+${file.additions}",
                color = Nord.green,
                fontSize = 12.sp,
                modifier = Modifier.padding(end = 8.dp)
            )
            Text(
                "-${file.deletions}",
                color = Nord.red,
                fontSize = 12.sp
            )
        }
    }
}

@Composable
fun DiffLineView(line: DiffLine) {
    val bgColor = when (line.kind) {
        LineKind.Addition -> Nord.green.copy(alpha = 0.15f)
        LineKind.Deletion -> Nord.red.copy(alpha = 0.15f)
        LineKind.Context -> Color.Transparent
    }
    
    val prefix = when (line.kind) {
        LineKind.Addition -> "+"
        LineKind.Deletion -> "-"
        LineKind.Context -> " "
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(bgColor)
            .padding(horizontal = 12.dp, vertical = 2.dp)
    ) {
        Text(
            prefix,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = when (line.kind) {
                LineKind.Addition -> Nord.green
                LineKind.Deletion -> Nord.red
                LineKind.Context -> Nord.textDim
            },
            modifier = Modifier.width(16.dp)
        )
        Text(
            line.content,
            fontFamily = FontFamily.Monospace,
            fontSize = 12.sp,
            color = Nord.text,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
fun SwipeActionBar(
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Nord.bgLight)
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        // Reject button
        Button(
            onClick = onReject,
            colors = ButtonDefaults.buttonColors(
                containerColor = Nord.red.copy(alpha = 0.2f)
            ),
            modifier = Modifier.weight(1f).padding(end = 8.dp)
        ) {
            Icon(
                Icons.Default.Close,
                contentDescription = "Reject",
                tint = Nord.red
            )
            Spacer(Modifier.width(8.dp))
            Text("Reject", color = Nord.red)
        }
        
        // Approve button
        Button(
            onClick = onApprove,
            colors = ButtonDefaults.buttonColors(
                containerColor = Nord.green.copy(alpha = 0.2f)
            ),
            modifier = Modifier.weight(1f).padding(start = 8.dp)
        ) {
            Icon(
                Icons.Default.Check,
                contentDescription = "Approve",
                tint = Nord.green
            )
            Spacer(Modifier.width(8.dp))
            Text("Approve", color = Nord.green)
        }
    }
}

@Composable
fun EmptyState(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = null,
                tint = Nord.green,
                modifier = Modifier.size(64.dp)
            )
            Spacer(Modifier.height(16.dp))
            Text(
                "All caught up!",
                fontSize = 18.sp,
                color = Nord.text
            )
            Text(
                "No pending reviews",
                fontSize = 14.sp,
                color = Nord.textDim
            )
        }
    }
}
