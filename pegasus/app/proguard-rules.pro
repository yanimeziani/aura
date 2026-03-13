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

# Enhanced Liquid Glass Render Engine optimizations
-keep class org.dragun.pegasus.ui.rendering.** { *; }
-keep class org.dragun.pegasus.ui.components.glass.** { *; }

# Compose and Material 3 optimizations
-dontwarn androidx.compose.ui.platform.compose_view_saveable_id_tag
-dontwarn androidx.compose.ui.platform.wrapper_ignored_for_test
-keep class androidx.compose.ui.platform.AndroidCompositionLocals_androidKt { *; }
-keep class androidx.compose.** { *; }
-keep class androidx.compose.material3.** { *; }

# Glass animation optimizations  
-keep class androidx.compose.animation.** { *; }
-keep class androidx.compose.foundation.gestures.** { *; }

# iOS 16 Typography preservation
-keep class org.dragun.pegasus.ui.theme.iOS16Typography { *; }
-keep class org.dragun.pegasus.ui.theme.iOS16TextStyles { *; }
-keep class org.dragun.pegasus.ui.theme.LiquidGlassTheme { *; }
-keep class org.dragun.pegasus.ui.theme.LiquidGlassColors { *; }

# Performance optimizations for release builds
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification

# Remove debug logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}
