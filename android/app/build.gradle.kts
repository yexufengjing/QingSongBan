plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yexufengjing.qingsongban"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yexufengjing.qingsongban"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 35
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseStoreFilePath = providers.environmentVariable("QSB_RELEASE_STORE_FILE").orNull
    val releaseStorePassword = providers.environmentVariable("QSB_RELEASE_STORE_PASSWORD").orNull
    val releaseKeyAlias = providers.environmentVariable("QSB_RELEASE_KEY_ALIAS").orNull
    val releaseKeyPassword = providers.environmentVariable("QSB_RELEASE_KEY_PASSWORD").orNull
    val releaseSigningReady = listOf(
        releaseStoreFilePath,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).all { !it.isNullOrBlank() }

    if (releaseSigningReady) {
        signingConfigs.create("qsbRelease") {
            storeFile = file(releaseStoreFilePath!!)
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("qsbRelease")
            }
        }
    }

    if (!releaseSigningReady) {
        tasks.configureEach {
            if (name == "assembleRelease" || name == "bundleRelease") {
                doFirst {
                    error(
                        "Release signing requires QSB_RELEASE_STORE_FILE, " +
                            "QSB_RELEASE_STORE_PASSWORD, QSB_RELEASE_KEY_ALIAS and " +
                            "QSB_RELEASE_KEY_PASSWORD",
                    )
                }
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
