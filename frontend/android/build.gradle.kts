import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Kotlin Gradle plugin version aligned with Kotlin in the project
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
        // Android Gradle Plugin 8.x (ensure your Gradle wrapper is compatible, e.g., 8.6/8.7)
        classpath("com.android.tools.build:gradle:8.5.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Set a shared build directory: <repo>/build (two levels up from android/)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(newBuildDir)

// Make each subproject build into <repo>/build/<moduleName>
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure :app is evaluated first (Flutter standard expectation)
subprojects {
    project.evaluationDependsOn(":app")
}

// Global Java/Kotlin toolchain compatibility to remove Java 8 obsolete warnings
// Note: Module-specific (e.g., android/app/build.gradle.kts) compileOptions/kotlinOptions
// should also be set; this sets a sane default for all subprojects.
subprojects {
    // Kotlin JVM target for all Kotlin compile tasks
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            kotlinOptions {
                jvmTarget = "17"
                // Opt-in to default method generation if needed by some libraries (optional)
                freeCompilerArgs = freeCompilerArgs + listOf("-Xjvm-default=all")
            }
        }
    }

    // For Java compilation tasks (non-Android modules)
    tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        options.encoding = "UTF-8"
    }
}

// Standard clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

