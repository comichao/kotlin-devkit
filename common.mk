# common.mk — shared build helpers for Kotlin/Gradle Android projects
# ---------------------------------------------------------------------------
# Include from a project's Makefile AFTER defining:
#
#   PKG      – Android application ID   (e.g. dev.pomo)
#   ACTIVITY – launcher activity        (optional, default .MainActivity)
#
# Machine-specific values (JAVA_HOME, ANDROID_HOME, ...) belong in your shell
# profile or in a git-ignored env.mk, never in version-controlled Makefiles.
# ---------------------------------------------------------------------------

_DEVKIT := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))

# Optional local overrides (git-ignored): devkit-wide, then project-wide.
-include $(_DEVKIT)/env.mk
-include env.mk

ACTIVITY ?= .MainActivity
ADB      ?= adb
# Gradle modules whose release APKs are verified and published (space separated).
MODULES  ?= app
PYTHON   ?= python3
# Prefer the project's Gradle wrapper, fall back to a system Gradle.
GRADLE   ?= $(if $(wildcard ./gradlew),./gradlew,gradle)
# Whatever APK the build produced (the project may rename it, e.g. to include the version).
# $(shell) runs when used, unlike $(wildcard), which caches directory contents from before the build.
APK         ?= $(shell ls app/build/outputs/apk/debug/*.apk 2>/dev/null | head -n1)

.PHONY: debug release publish install deploy run phone logcat logcat-save bump clean help

## debug: Build a debug APK
debug:
	$(GRADLE) assembleDebug

## release: Build signed release APKs for $(MODULES) and verify their version and signing key
release:
	@for v in KEYSTORE KEYSTORE_PASSWORD KEY_PASSWORD; do \
	   [ -n "$$(eval echo \"\$$$$v\")" ] || { echo "$$v is not set (see env.mk.example)"; exit 1; }; \
	 done; \
	 [ -f "$$KEYSTORE" ] || { echo "Keystore not found: $$KEYSTORE"; exit 1; }
	@for m in $(MODULES); do rm -f $$m/build/outputs/apk/release/*.apk; done
	$(GRADLE) assembleRelease
	@for m in $(MODULES); do \
	   [ "$$(ls $$m/build/outputs/apk/release/*.apk 2>/dev/null | wc -l)" = 1 ] || { echo "Expected exactly one release APK in $$m"; exit 1; }; \
	   $(PYTHON) $(_DEVKIT)/scripts/check_apk_version.py "$$(ls $$m/build/outputs/apk/release/*.apk)" || exit 1; \
	   echo "Release APK: $$(ls $$m/build/outputs/apk/release/*.apk)"; \
	 done

_publish-check:
	@[ -z "$$(git status --porcelain)" ] || { echo "Uncommitted changes: commit first"; exit 1; }
	@git rev-parse '@{u}' >/dev/null 2>&1 || { echo "Branch has no upstream: git push -u origin <branch> first"; exit 1; }
	@[ -z "$$(git log '@{u}..' --oneline)" ] || { echo "Unpushed commits: push first"; exit 1; }

## publish: Build the signed release APKs and upload them to a GitHub release tagged v<versionName>
publish: _publish-check release
	@VERSION=$$($(PYTHON) $(_DEVKIT)/scripts/bump_version.py | cut -d' ' -f1); \
	 DIR=$$(mktemp -d); trap 'rm -rf "$$DIR"' EXIT; \
	 for m in $(MODULES); do \
	   APK=$$(ls $$m/build/outputs/apk/release/*.apk); \
	   $(PYTHON) $(_DEVKIT)/scripts/check_apk_version.py "$$APK" || exit 1; \
	   cp "$$APK" "$$DIR/"; \
	 done; \
	 (cd "$$DIR" && sha256sum *.apk > SHA256SUMS); \
	 echo "Publishing v$$VERSION:"; ls "$$DIR"; \
	 gh release create "v$$VERSION" "$$DIR"/* --target "$$(git rev-parse HEAD)" \
	   --title "$(PKG) v$$VERSION" --generate-notes

## install: Push the debug APK to a connected device / emulator
install:
	@[ -f "$(APK)" ] || { echo "No APK at $(APK) — run 'make debug' first"; exit 1; }
	$(ADB) install -r "$(APK)"

## deploy: Build the debug APK then install it
deploy: debug install

## run: Launch the installed app (no rebuild)
run:
	$(ADB) shell am start -n $(PKG)/$(ACTIVITY)

## phone: Full workflow — build, install, launch
phone: deploy run

## logcat: Stream logcat for the app's process (app must be running)
logcat:
	@PID=$$($(ADB) shell pidof -s $(PKG)); \
	 [ -n "$$PID" ] || { echo "$(PKG) is not running — 'make run' first"; exit 1; }; \
	 $(ADB) logcat --pid=$$PID

## logcat-save: Capture the app's logcat to a timestamped file (Ctrl-C to stop)
logcat-save:
	@PID=$$($(ADB) shell pidof -s $(PKG)); \
	 [ -n "$$PID" ] || { echo "$(PKG) is not running — 'make run' first"; exit 1; }; \
	 FILE="logcat_$$(date +%Y%m%d_%H%M%S).txt"; \
	 echo "Saving logcat to $$FILE"; \
	 $(ADB) logcat --pid=$$PID | tee "$$FILE"

## bump: Bump versionName and versionCode  (PART=patch|minor|major or explicit X.Y.Z)
bump:
	@[ -n "$(PART)" ] || { echo "Usage: make bump PART=patch|minor|major|X.Y.Z"; exit 1; }
	$(PYTHON) $(_DEVKIT)/scripts/bump_version.py $(PART)

## clean: Remove Gradle build output
clean:
	$(GRADLE) clean

## help: List available targets
help:
	@grep -h '^## ' $(MAKEFILE_LIST) | sed 's/^## //' | awk -F': ' '{printf "  %-12s %s\n", $$1, $$2}'
