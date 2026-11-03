import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key (specs/16, step 7): CI writes android/key.properties and the keystore
// from secrets (tool/write_android_signing.sh). Without them — a local build — release
// builds fall back to the debug key, which no device or store accepts as an update.
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "ch.goomba.wuselwall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (README, "Gradle setup"): scheduled notifications on
        // older Android versions need core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "ch.goomba.wuselwall"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("upload") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName(if (keyPropertiesFile.exists()) "upload" else "debug")
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

dependencies {
    // Flutter integration_test exposes older AndroidX test APIs. Align only the
    // debug variant with instrumentation; release dependencies remain untouched.
    debugImplementation("androidx.test:runner:1.6.2")
    debugImplementation("androidx.test:rules:1.6.1")
    debugImplementation("androidx.test.espresso:espresso-core:3.6.1")
    debugImplementation("com.google.guava:guava:33.4.8-android")
    androidTestImplementation("com.google.guava:guava:33.4.8-android")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("com.google.android.apps.common.testing.accessibility.framework:accessibility-test-framework:4.1.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
