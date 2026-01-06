plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ushiomd"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ushiomd"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionName = flutter.versionName
        
        // Custom Version Code Formula: (Major + 1) * 1000 + Minor * 10 + Patch
        // Example: 1.0.0 -> 2000, 1.0.1 -> 2001, 1.1.0 -> 2010, 2.0.0 -> 3000
        val vParts = flutter.versionName?.split(".") ?: emptyList()
        if (vParts.size >= 3) {
            val major = vParts[0].toIntOrNull() ?: 0
            val minor = vParts[1].toIntOrNull() ?: 0
            val patch = vParts[2].substringBefore("+").toIntOrNull() ?: 0
            versionCode = (major + 1) * 1000 + (minor * 10) + patch
        } else {
            versionCode = flutter.versionCode
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 多架构 APK 分包配置
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true  // 同时生成通用 APK
        }
    }

    // APK 输出命名配置
    applicationVariants.all {
        outputs.all {
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val abiName = outputImpl.getFilter(com.android.build.OutputFile.ABI) ?: "universal"
            outputImpl.outputFileName = "ushio-md-v${versionName}-${abiName}.apk"
        }
    }
}

flutter {
    source = "../.."
}
