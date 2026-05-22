// Makes AGP classes (e.g. LibraryExtension) available to the root build script.
buildscript {
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
    }
}

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
// Older plugins (e.g. speech_to_text 5.x) don't — this fills the gap.
// plugins.withId fires at plugin-application time, avoiding afterEvaluate timing conflicts.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (namespace == null) {
                namespace = project.group.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
