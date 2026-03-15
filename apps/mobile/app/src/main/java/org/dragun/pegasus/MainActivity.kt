package org.dragun.pegasus

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import dagger.hilt.android.AndroidEntryPoint
import org.dragun.pegasus.ui.PegasusNavHost
import org.dragun.pegasus.ui.theme.PegasusMaterialTheme

@AndroidEntryPoint
class MainActivity : FragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PegasusMaterialTheme {
                PegasusNavHost()
            }
        }
    }
}
