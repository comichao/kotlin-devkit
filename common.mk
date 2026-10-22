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
PYTHON   ?= python3
# Prefer the project's Gradle wrapper, fall back to a system Gradle.
GRADLE   ?= $(if $(wildcard ./gradlew),./gradlew,gradle)
APK      ?= app/build/outputs/apk/debug/app-debug.apk
RELEASE_APK ?= app/build/outputs/apk/release/app-release.apk

.PHONY: debug release install deploy run phone logcat logcat-save bump clean help

## debug: Build a debug APK
debug:
	$(GRADLE) assembleDebug

## release: Build a signed release APK (needs KEYSTORE, KEYSTORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS)
release:
	@for v in KEYSTORE KEYSTORE_PASSWORD KEY_PASSWORD; do \
	   [ -n "$$(eval echo \"\$$$$v\")" ] || { echo "$$v is not set (see env.mk.example)"; exit 1; }; \
	 done; \
	 [ -f "$$KEYSTORE" ] || { echo "Keystore not found: $$KEYSTORE"; exit 1; }
	$(GRADLE) assembleRelease
	@echo "Release APK: $(RELEASE_APK)"

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
