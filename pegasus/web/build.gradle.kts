plugins {
    alias(libs.plugins.kotlin.jvm)
    application
}

kotlin {
    jvmToolchain(17)
}

application {
    mainClass.set("org.dragun.pegasus.web.ApplicationKt")
}

dependencies {
    implementation(libs.ktor.server.core)
    implementation(libs.ktor.server.netty)
    implementation(libs.logback.classic)
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "org.dragun.pegasus.web.ApplicationKt"
    }
}
