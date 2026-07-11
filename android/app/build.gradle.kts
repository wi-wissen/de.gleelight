import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties holds the release signing credentials and is deliberately not in git.
// Without it (fresh clone, CI without secrets) we fall back to debug signing, so the
// project still builds for everyone instead of failing during Gradle configuration.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "de.gleelight"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "de.gleelight"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Not distributable, but it builds and runs.
                signingConfigs.getByName("debug")
            }
        }
    }
}

afterEvaluate {
    val createNamedReleaseApk by tasks.registering {
        doLast {
            val versionName = project.findProperty("version-name")?.toString() ?: flutter.versionName.toString()
            val sourceApk = rootProject.layout.buildDirectory.file("app/outputs/flutter-apk/app-release.apk").get().asFile
            if (sourceApk.exists()) {
                val targetApk = sourceApk.parentFile.resolve("gleelight-${versionName}-release-arm64.apk")
                sourceApk.copyTo(targetApk, overwrite = true)
            }
        }
    }

    tasks.matching { it.name == "assembleRelease" }.configureEach {
        finalizedBy(createNamedReleaseApk)
    }
}

flutter {
    source = "../.."
}
