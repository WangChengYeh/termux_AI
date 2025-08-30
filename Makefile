## Make targets to build, test, and install Termux AI (aarch64-only)

# Configurable variables
GRADLEW ?= ./gradlew
MODULE ?= app
BUILD_TYPE ?= debug # debug|release
APP_ID ?= com.termux
MAIN_ACTIVITY ?= com.termux.app.TermuxActivity

# Derived values
APK_DIR := $(MODULE)/build/outputs/apk/$(BUILD_TYPE)
APK_BASENAME := $(MODULE)-$(BUILD_TYPE).apk
APK := $(APK_DIR)/$(APK_BASENAME)

.PHONY: help build release lint test clean install uninstall run logs devices abi verify-abi doctor

help:
	@echo "Termux AI Makefile (aarch64-only)"
	@echo "Available targets:"
	@echo "  build           - Assemble $(BUILD_TYPE) APK"
	@echo "  release         - Assemble release APK"
	@echo "  lint            - Run Android Lint for :$(MODULE)"
	@echo "  test            - Run unit tests"
	@echo "  clean           - Clean Gradle build outputs"
	@echo "  install         - Install built APK via adb (-r)"
	@echo "  uninstall       - Uninstall $(APP_ID) via adb"
	@echo "  run             - Launch $(MAIN_ACTIVITY) on device"
	@echo "  logs            - Tail logcat for $(APP_ID)"
	@echo "  devices         - List adb devices"
	@echo "  abi             - Show device ABI"
	@echo "  verify-abi      - Ensure connected device is arm64-v8a"
	@echo "Variables: BUILD_TYPE=debug|release, MODULE=$(MODULE), APP_ID=$(APP_ID)"

build:
	$(GRADLEW) :$(MODULE):assemble$$(echo $(BUILD_TYPE) | sed 's/.*/\U&/')
	@echo "Built: $(APK)"

release:
	$(GRADLEW) :$(MODULE):assembleRelease
	@echo "Release APKs under: $(MODULE)/build/outputs/apk/release/"

lint:
	$(GRADLEW) :$(MODULE):lint

test:
	$(GRADLEW) test

clean:
	$(GRADLEW) clean

install: build verify-abi
	@echo "Installing: $(APK)"
	adb install -r "$(APK)"

uninstall:
	adb uninstall "$(APP_ID)" || true

run:
	adb shell am start -n "$(APP_ID)/.app.TermuxActivity"

logs:
	adb logcat | sed -u -n '/$(APP_ID)/p'

devices:
	adb devices -l

abi:
	adb shell getprop ro.product.cpu.abi

verify-abi:
	@ABI=$$(adb shell getprop ro.product.cpu.abi | tr -d '\r'); \
	if [ "$$ABI" != "arm64-v8a" ]; then \
	  echo "Error: Connected device ABI '$$ABI' is not supported. aarch64 (arm64-v8a) only."; \
	  exit 1; \
	fi; \
	echo "Verified aarch64 device (arm64-v8a)."

doctor:
	@which adb >/dev/null 2>&1 || { echo "Please install Android Platform Tools (adb)"; exit 1; }
	@test -x "$(GRADLEW)" || { echo "Gradle wrapper not found/executable: $(GRADLEW)"; exit 1; }
	@echo "Environment looks OK."

