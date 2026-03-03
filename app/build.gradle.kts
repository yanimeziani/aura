plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "org.dragun.pegasus"
    compileSdk = 36

    defaultConfig {
        applicationId = "org.dragun.pegasus"
        minSdk = 28
        targetSdk = 36
        versionCode = 10
        versionName = "0.2.8"

        ndk {
            abiFilters += "arm64-v8a"
        }

        buildConfigField("String", "DEFAULT_API_URL", "\"https://ops.meziani.org\"")
    }

    signingConfigs {
        getByName("debug") {
            // uses default debug keystore
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
            
            // Enhanced optimization for liquid glass render engine
            ndk {
                debugSymbolLevel = "NONE"
            }
            
            // Enable R8 full mode for maximum optimization
            buildConfigField("boolean", "ENABLE_RENDER_ENGINE_DEBUG", "false")
            buildConfigField("boolean", "ENABLE_GLASS_ANIMATIONS", "true")
            buildConfigField("boolean", "ENABLE_HAPTIC_FEEDBACK", "true")
        }
        
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            
            buildConfigField("boolean", "ENABLE_RENDER_ENGINE_DEBUG", "true")
            buildConfigField("boolean", "ENABLE_GLASS_ANIMATIONS", "true")
            buildConfigField("boolean", "ENABLE_HAPTIC_FEEDBACK", "true")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        
        // Enable Compose optimizations for liquid glass effects
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

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
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

    implementation(libs.datastore)
    implementation(libs.coroutines)
}
