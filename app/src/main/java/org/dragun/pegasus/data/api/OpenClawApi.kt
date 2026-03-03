package org.dragun.pegasus.data.api

import org.dragun.pegasus.domain.model.*
import retrofit2.Response
import retrofit2.http.*

interface OpenClawApi {

    // Auth
    @POST("auth/login")
    suspend fun login(@Body req: LoginRequest): Response<TokenResponse>

    @POST("auth/logout")
    suspend fun logout(): Response<Map<String, String>>

    // Health (public)
    @GET("health")
    suspend fun health(): Response<HealthStatus>

    // Agents
    @GET("agents")
    suspend fun agents(): Response<Map<String, AgentInfo>>

    @POST("agents/{agent_id}/start")
    suspend fun startAgent(@Path("agent_id") agentId: String): Response<AgentControlResult>

    @POST("agents/{agent_id}/stop")
    suspend fun stopAgent(@Path("agent_id") agentId: String): Response<AgentControlResult>

    @GET("agents/{agent_id}/stream")
    suspend fun streamAgent(@Path("agent_id") agentId: String): Response<String>

    // HITL
    @GET("hitl/queue")
    suspend fun hitlQueue(@Query("status") status: String = "pending"): Response<HitlQueue>

    @GET("hitl/{item_id}")
    suspend fun hitlItem(@Path("item_id") itemId: String): Response<HitlItem>

    @POST("hitl/approve/{item_id}")
    suspend fun approve(@Path("item_id") itemId: String): Response<Map<String, String>>

    @POST("hitl/reject/{item_id}")
    suspend fun reject(@Path("item_id") itemId: String): Response<Map<String, String>>

    // Costs
    @GET("costs/status")
    suspend fun costStatus(): Response<CostStatus>

    @GET("costs/today")
    suspend fun costsToday(): Response<Map<String, Any>>

    // Panic
    @GET("panic")
    suspend fun panicStatus(): Response<PanicStatus>

    @POST("panic")
    suspend fun triggerPanic(@Query("reason") reason: String = "pegasus"): Response<PanicStatus>

    @DELETE("panic")
    suspend fun clearPanic(): Response<PanicStatus>

    // Tasks
    @POST("tasks/submit")
    suspend fun submitTask(@Body task: TaskSubmit): Response<TaskResult>

    @GET("tasks/queue/{agent_id}")
    suspend fun taskQueue(@Path("agent_id") agentId: String): Response<Map<String, Any>>
}
