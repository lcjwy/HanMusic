import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 本地 key.properties 或 CI 环境变量提供签名；release 禁止回退 debug 签名。
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(property: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: (keystoreProperties[property] as String?)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "HAN_MUSIC_STORE_FILE")
val releaseStorePassword = signingValue("storePassword", "HAN_MUSIC_STORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "HAN_MUSIC_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "HAN_MUSIC_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword,
).all { it != null }

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        check(hasReleaseSigning) {
            "Release signing is required. Configure android/key.properties or HAN_MUSIC_* signing environment variables."
        }
        check(file(releaseStoreFile!!).isFile) { "Release keystore file does not exist." }
    }
}

android {
    namespace = "com.han.music.han_music"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.han.music.han_music"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
            storeFile = releaseStoreFile?.let { file(it) }
            storePassword = releaseStorePassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
