package org.dragun.pegasus.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import org.dragun.pegasus.ui.screens.*

object Routes {
    const val LOGIN = "login"
    const val DASHBOARD = "dashboard"
    const val HITL = "hitl"
    const val COSTS = "costs"
    const val TERMINAL = "terminal"
    const val SETTINGS = "settings"
    const val AGENT_STREAM = "agent_stream"
    const val AGENT_CHAT = "agent_chat"
}

@Composable
fun PegasusNavHost() {
    val navController = rememberNavController()
    val loginVm: LoginViewModel = hiltViewModel()
    val isLoggedIn by loginVm.isLoggedIn.collectAsState(initial = false)

    val startDest = if (isLoggedIn) Routes.DASHBOARD else Routes.LOGIN

    NavHost(navController = navController, startDestination = startDest) {
        composable(Routes.LOGIN) {
            LoginScreen(
                viewModel = loginVm,
                onLoginSuccess = {
                    navController.navigate(Routes.DASHBOARD) {
                        popUpTo(Routes.LOGIN) { inclusive = true }
                    }
                },
            )
        }
        composable(Routes.DASHBOARD) {
            DashboardScreen(
                onNavigate = { navController.navigate(it) },
                onLogout = {
                    navController.navigate(Routes.LOGIN) {
                        popUpTo(Routes.DASHBOARD) { inclusive = true }
                    }
                },
            )
        }
        composable(Routes.HITL) {
            HitlScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.COSTS) {
            CostsScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.TERMINAL) {
            TerminalScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.SETTINGS) {
            SettingsScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.AGENT_STREAM + "/{agentId}") { backStackEntry ->
            val agentId = backStackEntry.arguments?.getString("agentId") ?: ""
            AgentStreamScreen(
                agentId = agentId,
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.AGENT_CHAT + "/{agentId}") { backStackEntry ->
            val agentId = backStackEntry.arguments?.getString("agentId") ?: ""
            AgentChatScreen(
                agentId = agentId,
                onBack = { navController.popBackStack() },
            )
        }
    }
}
