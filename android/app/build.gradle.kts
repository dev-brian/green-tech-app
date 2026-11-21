import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Enable Google services plugin for Firebase (declared in root build file)
    // TODO(firebase): descomenta esta linea cuando agregues tu
    // android/app/google-services.json real (via `flutterfire configure`).
    // Mientras el archivo no exista, este plugin hace fallar el build de Android.
    // id("com.google.gms.google-services")
}

// Firma release propia (checklist de servicios en la nube, sección 18).
// android/key.properties y el .jks NO se versionan (ver android/.gitignore):
// en el CI se generan desde GitHub Secrets; en local, ver docs/release-android.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val tieneFirmaRelease = keystorePropertiesFile.exists()
if (tieneFirmaRelease) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "mx.greentech.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications (usa APIs de java.time
        // vía desugaring para poder correr en minSdk < 26).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "mx.greentech.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth y flutter_secure_storage requieren Android 6.0 (API 23)+
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (tieneFirmaRelease) {
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
            // Con android/key.properties se firma con la llave del equipo.
            // Sin él (p. ej. un clon nuevo) se usa la llave debug para que
            // `flutter run --release` siga funcionando; ese APK no se publica.
            signingConfig = if (tieneFirmaRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Requerido por flutter_local_notifications (core library desugaring).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
