// plugins {
//     id("com.android.application")
//     id("com.google.gms.google-services")
//     id("kotlin-android")
//     id("dev.flutter.flutter-gradle-plugin")
// }

// android {
//     namespace = "com.safety.orbit_shield"
//     compileSdk = 36
//     ndkVersion = "27.0.12077973"

//     compileOptions {
//         sourceCompatibility = JavaVersion.VERSION_11
//         targetCompatibility = JavaVersion.VERSION_11
//     }

//     kotlinOptions {
//         jvmTarget = JavaVersion.VERSION_11.toString()
//     }
    
//     // vvv CORRECTED FLAVOR CONFIGURATION for .kts vvv
//     flavorDimensions.add("app")
//     productFlavors {
//         create("parent") {
//             dimension = "app"
//             applicationIdSuffix = ".parent"
//         }
//         create("child") {
//             dimension = "app"
//             applicationIdSuffix = ".child"
//         }
//     }
//     // ^^^ END OF FLAVOR CONFIGURATION ^^^

//     defaultConfig {
//         applicationId = "com.safety.orbit_shield"
//         minSdk = flutter.minSdkVersion
//         targetSdk = 34
//         multiDexEnabled = true
//     }

//     buildTypes {
//         release {
//             signingConfig = signingConfigs.getByName("debug")
//         }
//     }
// }

// flutter {
//     source = "../.."
// }

// dependencies {
//     implementation(kotlin("stdlib-jdk8"))
//     implementation("androidx.multidex:multidex:2.0.1")
    
// }



plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.safety.orbit_shield"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // vvv ADD THIS LINE vvv
        isCoreLibraryDesugaringEnabled = true
        // ^^^ END OF NEW LINE ^^^
        sourceCompatibility = JavaVersion.VERSION_1_8 // Desugaring works best with Java 8
        targetCompatibility = JavaVersion.VERSION_1_8 // Desugaring works best with Java 8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString() // Match the Java version
    }
    
    flavorDimensions.add("app")
    productFlavors {
        create("parent") {
            dimension = "app"
            applicationIdSuffix = ".parent"
        }
        create("child") {
            dimension = "app"
            applicationIdSuffix = ".child"
        }
    }

    defaultConfig {
        applicationId = "com.safety.orbit_shield"
        minSdk = flutter.minSdkVersion // Required for multidex
        targetSdk = 34
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(kotlin("stdlib-jdk8"))
    implementation("androidx.multidex:multidex:2.0.1")
    // vvv ADD THIS LINE vvv
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // ^^^ END OF NEW LINE ^^^
}
