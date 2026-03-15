package org.dragun.pegasus.data.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import dagger.hilt.android.qualifiers.ApplicationContext
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages biometric-bound encryption keys in Android Keystore.
 * Tokens are encrypted with AES-GCM using a key that requires biometric
 * authentication before each use.
 */
@Singleton
class BiometricHelper @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "pegasus_biometric_key"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_LENGTH = 128
    }

    private val keyStore: KeyStore =
        KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    /** True when device has enrolled biometric hardware (fingerprint / face). */
    fun canUseBiometric(): Boolean {
        val bm = BiometricManager.from(context)
        return bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    /**
     * Returns an ENCRYPT-mode cipher bound to biometric auth.
     * The caller must wrap this in a [BiometricPrompt.CryptoObject] — the
     * Keystore will block [Cipher.doFinal] until the user authenticates.
     */
    fun getEncryptCipher(): Cipher? {
        return try {
            val key = getOrCreateKey()
            Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.ENCRYPT_MODE, key)
            }
        } catch (_: KeyPermanentlyInvalidatedException) {
            deleteKey()
            null
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Returns a DECRYPT-mode cipher initialised with the stored IV.
     * Must be authenticated via BiometricPrompt before [Cipher.doFinal].
     */
    fun getDecryptCipher(ivBase64: String): Cipher? {
        return try {
            val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey ?: return null
            val iv = Base64.decode(ivBase64, Base64.NO_WRAP)
            Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_LENGTH, iv))
            }
        } catch (_: KeyPermanentlyInvalidatedException) {
            deleteKey()
            null
        } catch (_: Exception) {
            null
        }
    }

    /** Encrypt [plaintext] with an already-authenticated cipher. */
    fun encrypt(cipher: Cipher, plaintext: String): EncryptedData {
        val encrypted = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        return EncryptedData(
            ciphertext = Base64.encodeToString(encrypted, Base64.NO_WRAP),
            iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
        )
    }

    /** Decrypt [ciphertext] with an already-authenticated cipher. */
    fun decrypt(cipher: Cipher, ciphertext: String): String {
        val data = Base64.decode(ciphertext, Base64.NO_WRAP)
        return String(cipher.doFinal(data), Charsets.UTF_8)
    }

    fun hasKey(): Boolean = keyStore.containsAlias(KEY_ALIAS)

    fun deleteKey() {
        if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS)
        }
    }

    private fun getOrCreateKey(): SecretKey {
        keyStore.getKey(KEY_ALIAS, null)?.let { return it as SecretKey }
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
            .apply { init(spec) }
            .generateKey()
    }

    data class EncryptedData(val ciphertext: String, val iv: String)
}
