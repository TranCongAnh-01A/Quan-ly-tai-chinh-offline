allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    // Fix cho các plugin cũ (VD: isar_flutter_libs) chưa khai báo namespace
    // mà AGP 8+ yêu cầu bắt buộc. Đọc package từ AndroidManifest.xml để inject.
    project.plugins.withId("com.android.library") {
        project.extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (namespace.isNullOrEmpty()) {
                val manifest = project.file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val match = Regex("""package\s*=\s*"([^"]+)"""").find(manifest.readText())
                    namespace = match?.groupValues?.get(1)
                }
            }

        }
    }

    // Đồng bộ compileSdk của mọi plugin với app.
    //
    // isar_flutter_libs compile bằng SDK cũ nên bản release chết ở
    // `verifyReleaseResources`: "resource android:attr/lStar not found"
    // (lStar là attribute của androidx core, cần compileSdk >= 31).
    //
    // Phải đặt trong afterEvaluate: nếu gán sớm hơn thì chính build script của
    // plugin đó chạy sau và ghi đè lại giá trị của mình.
    //
    // Bỏ qua project đã đánh giá xong (`:app` bị evaluationDependsOn ở trên
    // kéo lên sớm) — gọi afterEvaluate lúc đó sẽ ném lỗi, mà `:app` vốn đã
    // đặt compileSdk = 36 rồi.
    if (!project.state.executed) {
        project.afterEvaluate {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
