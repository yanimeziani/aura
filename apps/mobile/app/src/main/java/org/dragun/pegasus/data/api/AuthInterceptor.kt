package org.dragun.pegasus.data.api

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import org.dragun.pegasus.data.store.SessionStore
import javax.inject.Inject

class AuthInterceptor @Inject constructor(
    private val sessionStore: SessionStore,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()

        if (original.url.encodedPath.startsWith("/auth/") ||
            original.url.encodedPath == "/health"
        ) {
            return chain.proceed(original)
        }

        val token = runBlocking { sessionStore.token.first() }
        if (token.isNullOrBlank()) return chain.proceed(original)

        val authed = original.newBuilder()
            .header("Authorization", "Bearer $token")
            .build()
        return chain.proceed(authed)
    }
}
