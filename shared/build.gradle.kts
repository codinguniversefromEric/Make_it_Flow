plugins {
    kotlin("multiplatform") version "1.9.22"
}

kotlin {
    val xcframeworkName = "FlowShared"

    iosX64()
    iosArm64()
    iosSimulatorArm64()

    targets.withType<org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget> {
        binaries.framework {
            baseName = xcframeworkName
        }
    }

    sourceSets {
        commonMain.dependencies {
            // dependencies
        }
    }
}
