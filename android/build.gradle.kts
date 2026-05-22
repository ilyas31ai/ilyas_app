plugins {
    id("com.google.gms.google-services") version "4.3.15" apply false
}
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires every library module to declare a namespace.
// Older plugins (e.g. speech_to_text 5.x) don't — this fills in the gap.
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val lib = project.extensions
                .findByType<com.android.build.gradle.LibraryExtension>()
            if (lib != null && lib.namespace == null) {
                lib.namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
