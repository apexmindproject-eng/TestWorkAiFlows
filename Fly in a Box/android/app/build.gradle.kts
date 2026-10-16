plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.flyinabox.app"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.flyinabox.app"
        minSdk = 26
        targetSdk = 28           // deliberate: apps targeting 29+ may not execute files in their own storage, and the fly's runtime lives there
        versionCode = 2
        versionName = "2.0"
    }
    flavorDimensions += "cpu"
    productFlavors {
        create("arm64") { dimension = "cpu" }                      // phones (the runtime in src/arm64/assets)
        create("x86") { dimension = "cpu"; versionNameSuffix = "-x86_64" }   // the emulator used by the tests
    }
    buildTypes { release { isMinifyEnabled = false } }
    androidResources { noCompress += listOf("bin") }                // runtime.bin is the xz tarball; named .bin because aapt unpacks .gz assets, and stored as is so it can be opened by descriptor
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    packaging { jniLibs { useLegacyPackaging = false } }
}
dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("org.apache.commons:commons-compress:1.26.2")
    implementation("org.tukaani:xz:1.9")
}
