plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // 🔄 corretto nome del plugin Kotlin
    // Il plugin Flutter deve restare dopo Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Plugin di Google Services per Firebase
    id("com.google.gms.google-services")
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
        // ✅ Application ID (identificativo univoco)
        applicationId = "com.example.occhio_al_borgo"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Per ora usa la chiave di debug per buildare anche in release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Importa il BoM (Bill of Materials) di Firebase
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))
    

    // ✅ Esempio di moduli Firebase (aggiungi quelli che ti servono)
    implementation("com.google.firebase:firebase-analytics") // Tracciamento base
    // implementation("com.google.firebase:firebase-auth") // 🔓 Autenticazione (se la vuoi)
    // implementation("com.google.firebase:firebase-firestore") // 💾 Database
    // implementation("com.google.firebase:firebase-storage") // ☁️ Storage

    // Le librerie standard Android già presenti
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
}



