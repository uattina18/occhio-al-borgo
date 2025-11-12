// File: android/app/build.gradle

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // 🔄 Plugin Kotlin corretto
    id("dev.flutter.flutter-gradle-plugin") // 🔧 Plugin Flutter
    id("com.google.gms.google-services") // ✅ Plugin Google Services per Firebase
}

android {
    namespace = "com.example.occhio_al_borgo"
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
        // ✅ Identificativo univoco dell'app
        applicationId = "com.example.occhio_al_borgo"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 🔐 Per ora usa la chiave di debug per buildare anche in release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase Bill of Materials (BOM)
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))

    // ✅ Moduli Firebase — attiva solo quelli che usi effettivamente
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    // implementation("com.google.firebase:firebase-storage")

    // ✅ Librerie Android standard
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
}
