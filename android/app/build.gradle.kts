import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {

    namespace = "com.example.needin_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ── REMOVED: keepDebugSymbols bloat ──────────────────────────────────
    // The previous config kept ALL .so debug symbols, inflating the APK by
    // ~100–150 MB. Release builds strip native debug symbols by default when
    // this block is absent. Only restore if you need native crash symbolication
    // via a dedicated symbols upload to Firebase Crashlytics / Play Console.

    defaultConfig {
        applicationId = "com.needin.express"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Load API key from local.properties (not committed to git)
        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localProperties.load(localPropertiesFile.inputStream())
        }
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            localProperties.getProperty("GOOGLE_MAPS_API_KEY", "")
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(keystorePropertiesFile.inputStream())
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            // ── Code shrinking & resource shrinking (R8) ─────────────────
            // minifyEnabled runs R8 (the successor to ProGuard) which:
            //   - removes unused Java/Kotlin code
            //   - obfuscates class/method names (smaller .dex)
            // shrinkResources removes unused Android XML resources.
            // Both are safe — Flutter Dart code is AOT-compiled separately
            // and is unaffected by R8. Only the Android wrapper/plugins shrink.
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ── ABI note ─────────────────────────────────────────────────────────
    // Flutter's Gradle plugin internally sets ndk.abiFilters, which conflicts
    // with an explicit splits { abi } block in KTS. Use the CLI flag instead:
    //   flutter build apk --release --split-per-abi
    // This produces one APK per architecture without any Gradle-level conflict.

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
