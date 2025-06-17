plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // ✅ 명시적으로 요구되는 버전으로 설정

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        minSdk = 24                    // ✅ 오류 해결: flutter_sound 플러그인 최소 요구 버전
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.0") // ✅ Kotlin 표준 라이브러리 추가
    implementation("androidx.core:core-ktx:1.10.0") // ✅ AndroidX Core KTX 라이브러리 추가
    implementation("androidx.appcompat:appcompat:1.6.1") // ✅ AppCompat 라이브러리 추가
    implementation("com.google.android.material:material:1.9.0") // ✅ Material Components 라이브러리 추가
}