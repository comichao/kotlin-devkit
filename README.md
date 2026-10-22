# kotlin-devkit

Shared Makefile helpers for Kotlin/Gradle Android apps. Same target names as
[kivy-devkit](https://github.com/comichao/kivy-devkit), but built on Gradle and adb.

## Use

```bash
git submodule add git@github.com:comichao/kotlin-devkit.git kotlin-devkit
```

Project `Makefile`:

```makefile
PKG := dev.pomo
include kotlin-devkit/common.mk
```

## Targets

```
make debug       Build a debug APK (./gradlew or gradle assembleDebug)
make release     Build a signed release APK (see below)
make install     adb install -r the APK
make deploy      debug + install
make run         Launch the app
make phone       deploy + run
make logcat      Stream logcat for the app's process
make logcat-save Same, tee'd to a timestamped file
make bump PART=patch|minor|major|X.Y.Z   Bump versionName and versionCode
make clean
make help
```

Variables: `PKG` (required), `ACTIVITY` (default `.MainActivity`), `GRADLE`, `ADB`, `APK`.
Machine-specific settings go in a git-ignored `env.mk` (see `env.mk.example`).

## Release

`make release` runs `assembleRelease` after checking that `KEYSTORE`,
`KEYSTORE_PASSWORD` and `KEY_PASSWORD` are set (put them in `env.mk`, see
`env.mk.example`). The project's `app/build.gradle.kts` must read them for its
release signing config:

```kotlin
signingConfigs {
    create("release") {
        storeFile = System.getenv("KEYSTORE")?.let { file(it) }
        storePassword = System.getenv("KEYSTORE_PASSWORD")
        keyAlias = System.getenv("KEY_ALIAS") ?: "release"
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
buildTypes { release { signingConfig = signingConfigs.getByName("release") } }
```

Play upload is not covered yet.
