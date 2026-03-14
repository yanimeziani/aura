package org.dragun.pegasus.data.api

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Interceptor
import okhttp3.Response
import org.dragun.pegasus.BuildConfig
import org.dragun.pegasus.data.store.SessionStore
import javax.inject.Inject

class BaseUrlInterceptor @Inject constructor(
    private val sessionStore: SessionStore,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()
        val configuredUrl = runBlocking { sessionStore.apiUrl.first() }
            ?.trim()
            ?.ifBlank { null }
            ?: BuildConfig.DEFAULT_API_URL

        val baseUrl = configuredUrl.toHttpUrlOrNull() ?: return chain.proceed(original)

        val rewrittenUrl = original.url.newBuilder()
            .scheme(baseUrl.scheme)
            .host(baseUrl.host)
            .port(baseUrl.port)
            .build()

        val rewritten = original.newBuilder()
            .url(rewrittenUrl)
            .build()

        return chain.proceed(rewritten)
    }
}
