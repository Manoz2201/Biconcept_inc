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

fun Project.forceCompileSdk36() {
    val android = extensions.findByName("android") ?: return
    for (name in listOf("setCompileSdk", "setCompileSdkVersion")) {
        try {
            val method = android.javaClass.methods.firstOrNull { it.name == name && it.parameterCount == 1 } ?: continue
            method.invoke(android, 36)
        } catch (_: Exception) {
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    afterEvaluate { forceCompileSdk36() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
