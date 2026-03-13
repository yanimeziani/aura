package org.dragun.pegasus.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelsTest {

    @Test
    fun `task submit defaults to normal priority`() {
        val task = TaskSubmit(agent_id = "meziani-main", description = "Run health check")
        assertEquals("normal", task.priority)
    }

    @Test
    fun `cost status panic mirrors panic flag`() {
        val status = CostStatus(
            date = "2026-03-04",
            panic_active = true,
            agents = mapOf(
                "meziani-main" to CostEntry(spent_usd = 3.2, cap_usd = 5.0, pct = 64.0, status = "ok"),
            ),
        )

        assertTrue(status.panic_active)
        assertEquals(1, status.agents.size)
    }

    @Test
    fun `server config keeps secure defaults`() {
        val config = ServerConfig(apiUrl = "https://api.pegasus.meziani.org")
        assertEquals(22, config.sshPort)
        assertEquals("root", config.sshUser)
        assertFalse(config.apiUrl.startsWith("http://"))
    }
}
