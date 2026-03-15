plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

val releaseKeystorePath = providers.gradleProperty("PEGASUS_RELEASE_STORE_FILE")
    .orElse(providers.environmentVariable("PEGASUS_RELEASE_STORE_FILE"))
val releaseKeystorePassword = providers.gradleProperty("PEGASUS_RELEASE_STORE_PASSWORD")
    .orElse(providers.environmentVariable("PEGASUS_RELEASE_STORE_PASSWORD"))
val releaseKeyAlias = providers.gradleProperty("PEGASUS_RELEASE_KEY_ALIAS")
    .orElse(providers.environmentVariable("PEGASUS_RELEASE_KEY_ALIAS"))
val releaseKeyPassword = providers.gradleProperty("PEGASUS_RELEASE_KEY_PASSWORD")
    .orElse(providers.environmentVariable("PEGASUS_RELEASE_KEY_PASSWORD"))

val hasReleaseSigning =
    releaseKeystorePath.isPresent &&
        releaseKeystorePassword.isPresent &&
        releaseKeyAlias.isPresent &&
        releaseKeyPassword.isPresent

android {
    namespace = "org.dragun.pegasus"
    compileSdk = 35

    defaultConfig {
        applicationId = "org.dragun.pegasus"
        minSdk = 28
        targetSdk = 35
        versionCode = 15
        versionName = "0.4.0"

        ndk {
            abiFilters += "arm64-v8a"
        }

        buildConfigField("String", "DEFAULT_API_URL", "\"https://api.pegasus.meziani.org\"")
    }

    signingConfigs {
        getByName("debug") {
            // uses default debug keystore
        }

        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath.get())
                storePassword = releaseKeystorePassword.get()
                keyAlias = releaseKeyAlias.get()
                keyPassword = releaseKeyPassword.get()
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            
            // Enhanced optimization for Material motion rendering
            ndk {
                debugSymbolLevel = "NONE"
            }
            
            // Enable R8 full mode for maximum optimization
            buildConfigField("boolean", "ENABLE_MOTION_DEBUG", "false")
            buildConfigField("boolean", "ENABLE_MATERIAL_ANIMATIONS", "true")
            buildConfigField("boolean", "ENABLE_HAPTIC_FEEDBACK", "true")
        }
        
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            
            buildConfigField("boolean", "ENABLE_MOTION_DEBUG", "true")
            buildConfigField("boolean", "ENABLE_MATERIAL_ANIMATIONS", "true")
            buildConfigField("boolean", "ENABLE_HAPTIC_FEEDBACK", "true")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        
        // Enable Compose optimizations for motion and transitions
        freeCompilerArgs += listOf(
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.animation.ExperimentalAnimationApi",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi"
        )
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
    
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/versions/9/OSGI-INF/MANIFEST.MF",
                "META-INF/LICENSE.md",
                "META-INF/NOTICE.md"
            )
        }
    }
}

tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Fails if release signing config is missing"
    doLast {
        check(hasReleaseSigning) {
            "Release signing credentials are missing. Set PEGASUS_RELEASE_STORE_FILE, PEGASUS_RELEASE_STORE_PASSWORD, PEGASUS_RELEASE_KEY_ALIAS, PEGASUS_RELEASE_KEY_PASSWORD."
        }
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.compose.adaptive)
    implementation(libs.compose.adaptive.layout)
    implementation(libs.compose.adaptive.navigation)
    implementation(libs.window)
    implementation(libs.compose.icons)
    implementation(libs.compose.preview)
    debugImplementation(libs.compose.tooling)

    implementation(libs.activity.compose)
    implementation(libs.navigation.compose)
    implementation(libs.lifecycle.runtime)
    implementation(libs.lifecycle.viewmodel)

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation)

    implementation(libs.retrofit)
    implementation(libs.retrofit.gson)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)

    implementation(libs.sshj)

    implementation(libs.biometric)
    implementation(libs.datastore)
    implementation(libs.coroutines)

    testImplementation(libs.junit4)
}
