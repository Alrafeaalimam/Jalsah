import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.mikrotik_cards_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mikrotik_cards_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD")
            val storeFileProp = keystoreProperties.getProperty("storeFile") ?: System.getenv("KEYSTORE_PATH")
            val storePasswordProp = keystoreProperties.getProperty("storePassword") ?: System.getenv("KEYSTORE_PASSWORD")

            if (storeFileProp != null && keyAliasProp != null) {
                val resolvedStoreFile = rootProject.file(storeFileProp)
                val targetFile = if (resolvedStoreFile.exists()) resolvedStoreFile else file(storeFileProp)
                if (targetFile.exists()) {
                    keyAlias = keyAliasProp
                    keyPassword = keyPasswordProp
                    storeFile = targetFile
                    storePassword = storePasswordProp
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseConfig = signingConfigs.findByName("release")
            if (releaseConfig?.storeFile != null && releaseConfig.storeFile!!.exists()) {
                signingConfig = releaseConfig
                println(">>> [Jalsah Release Signing]: Using RELEASE keystore: ${releaseConfig.storeFile!!.absolutePath}")
            } else {
                if (System.getenv("REQUIRE_RELEASE_KEYSTORE") == "true" || project.hasProperty("requireReleaseSigning")) {
                    throw GradleException("FATAL: Release keystore is required (REQUIRE_RELEASE_KEYSTORE=true or -PrequireReleaseSigning), but key.properties or keystore file was not found! Aborting release build to prevent silent debug signing.")
                }
                // Fallback to debug keystore for development / preview builds when release keystore is absent
                signingConfig = signingConfigs.getByName("debug")
                logger.warn("********************************************************************************")
                logger.warn(">>> [Jalsah Signing NOTICE]: 'key.properties' or release keystore not found.")
                logger.warn(">>> [Jalsah Signing NOTICE]: Falling back to local Android Debug keystore.")
                logger.warn(">>> [Jalsah Signing NOTICE]: To enforce production signing in CI/CD, set REQUIRE_RELEASE_KEYSTORE=true.")
                logger.warn("********************************************************************************")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
