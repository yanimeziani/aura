# Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class retrofit2.** { *; }
-keep class com.google.gson.** { *; }

# SSHJ
-keep class net.schmizz.** { *; }
-keep class com.hierynomus.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.slf4j.**
-dontwarn javax.security.auth.login.**
-dontwarn org.ietf.jgss.**
-dontwarn sun.security.x509.**
-dontwarn net.i2p.crypto.eddsa.**

# Pegasus API models
-keep class org.dragun.pegasus.domain.model.** { *; }
-keep class org.dragun.pegasus.data.api.** { *; }
