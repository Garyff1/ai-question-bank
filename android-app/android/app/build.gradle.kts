import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    FileInputStream(signingPropertiesFile).use(signingProperties::load)
}

fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: signingProperties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }

val releaseStorePath = signingValue("AIQB_RELEASE_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingValue("AIQB_RELEASE_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("AIQB_RELEASE_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("AIQB_RELEASE_KEY_PASSWORD", "keyPassword")
val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val allowDebugReleaseSigning =
    (System.getenv("AIQB_ALLOW_DEBUG_RELEASE_SIGNING")
        ?: signingProperties.getProperty("allowDebugReleaseSigning")
        ?: "false").toBoolean()

android {
    namespace = "com.garyff.aiquestionbank.ai_question_bank_android"
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
        applicationId = "com.garyff.aiquestionbank.ai_question_bank_android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseSigning -> signingConfigs.getByName("release")
                allowDebugReleaseSigning -> signingConfigs.getByName("debug")
                else -> throw GradleException(
                    "Release signing is not configured. Provide AIQB_RELEASE_* environment " +
                        "variables or android/key.properties. Debug signing is allowed only " +
                        "when AIQB_ALLOW_DEBUG_RELEASE_SIGNING=true is explicitly set.",
                )
            }
            // 关闭 R8 代码压缩/混淆：避免 ML Kit 等插件反射调用的类被错误移除。
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // ML Kit 默认只携带拉丁字符模型；中文教材识别需要显式加入中文模型。
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}

flutter {
    source = "../.."
}
