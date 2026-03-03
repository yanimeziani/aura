package org.dragun.pegasus

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dagger.hilt.android.AndroidEntryPoint
import org.dragun.pegasus.ui.PegasusNavHost
import org.dragun.pegasus.ui.theme.LiquidGlassTheme

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LiquidGlassTheme {
                PegasusNavHost()
            }
        }
    }
}
