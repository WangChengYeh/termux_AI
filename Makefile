## Make targets to build, test, and install Termux AI (aarch64-only)

# Configurable variables
GRADLEW ?= ./gradlew
MODULE ?= app
BUILD_TYPE ?= debug # debug|release
APP_ID ?= com.termux
MAIN_ACTIVITY ?= com.termux.app.TermuxActivity

# Derived values - Use correct APK filenames based on build type
ifeq ($(strip $(BUILD_TYPE)),debug)
APK_DIR := $(MODULE)/build/outputs/apk/debug
APK_BASENAME := termux-app_apt-android-7-debug_arm64-v8a.apk
else
APK_DIR := $(MODULE)/build/outputs/apk/release
APK_BASENAME := termux-app_apt-android-7-release_universal.apk
endif
APK := $(APK_DIR)/$(APK_BASENAME)

.PHONY: help build release lint test clean install uninstall run logs devices abi verify-abi doctor sop-help sop-list sop-download sop-extract sop-analyze sop-copy sop-update sop-build sop-add-package

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
	@echo ""
	@echo "SOP Package Integration:"
	@echo "  sop-help        - Show SOP usage and examples"
	@echo "  sop-add-package - Complete SOP workflow for PACKAGE_NAME"
	@echo "  sop-list        - List available packages (LETTER=n for nodejs)"
	@echo "  sop-download    - Download package PACKAGE_NAME and VERSION"
	@echo "  sop-extract     - Extract package PACKAGE_NAME"
	@echo "  sop-analyze     - Analyze extracted package structure"
	@echo "  sop-copy        - Copy package files to Android structure"
	@echo "  sop-update      - Update TermuxInstaller.java (if needed)"
	@echo "  sop-build       - Build and test integration"
	@echo ""
	@echo "Variables: BUILD_TYPE=debug|release, MODULE=$(MODULE), APP_ID=$(APP_ID)"
	@echo "SOP Variables: PACKAGE_NAME, VERSION, LETTER (for browsing)"

build:
	@if [ "$(strip $(BUILD_TYPE))" = "debug" ]; then \
		$(GRADLEW) assembleDebug; \
	else \
		$(GRADLEW) assembleRelease; \
	fi
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

##
## SOP Package Integration Targets
##

# SOP Variables
PACKAGES_DIR ?= packages
JNILIBS_DIR ?= app/src/main/jniLibs/arm64-v8a
PACKAGE_NAME ?= 
VERSION ?= 
LETTER ?= 

sop-help:
	@echo "SOP Package Integration - Standard Operating Procedure"
	@echo ""
	@echo "Complete workflow:"
	@echo "  make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0"
	@echo ""
	@echo "Individual steps:"
	@echo "  make sop-list LETTER=n                    # List packages starting with 'n'"
	@echo "  make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0"
	@echo "  make sop-extract PACKAGE_NAME=nodejs"
	@echo "  make sop-analyze PACKAGE_NAME=nodejs"
	@echo "  make sop-copy PACKAGE_NAME=nodejs"
	@echo "  make sop-update PACKAGE_NAME=nodejs      # Updates TermuxInstaller.java if needed"
	@echo "  make sop-build                           # Build and test integration"
	@echo ""
	@echo "Examples:"
	@echo "  make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1"
	@echo "  make sop-add-package PACKAGE_NAME=nano VERSION=8.2"
	@echo "  make sop-list LETTER=liba                # List lib* packages"

sop-add-package: sop-download sop-extract sop-analyze sop-copy sop-update sop-build
	@echo "✅ SOP Integration completed for $(PACKAGE_NAME)"

sop-list:
	@if [ -z "$(LETTER)" ]; then \
		echo "Usage: make sop-list LETTER=n"; \
		echo "Example: make sop-list LETTER=liba"; \
		exit 1; \
	fi
	@echo "📋 SOP Step 1: List available packages starting with '$(LETTER)'"
	@curl -s "https://packages.termux.dev/apt/termux-main/pool/main/$(LETTER)/" | grep -o 'href="[^"]*\.deb"' | sed 's/href="//g' | sed 's/"//g' || true

sop-download:
	@if [ -z "$(PACKAGE_NAME)" ] || [ -z "$(VERSION)" ]; then \
		echo "Usage: make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0"; \
		exit 1; \
	fi
	@echo "⬇️ SOP Step 2: Download $(PACKAGE_NAME) version $(VERSION)"
	@mkdir -p $(PACKAGES_DIR)
	@# Determine the correct URL path based on package name first letter
	@FIRST_LETTER=$$(echo "$(PACKAGE_NAME)" | cut -c1); \
	if echo "$(PACKAGE_NAME)" | grep -q "^lib"; then \
		URL_PATH="$$(echo "$(PACKAGE_NAME)" | cut -c1-4)"; \
	else \
		URL_PATH="$$FIRST_LETTER"; \
	fi; \
	PKG_URL="https://packages.termux.dev/apt/termux-main/pool/main/$$URL_PATH/$(PACKAGE_NAME)/$(PACKAGE_NAME)_$(VERSION)_aarch64.deb"; \
	echo "Downloading from: $$PKG_URL"; \
	wget -O $(PACKAGES_DIR)/$(PACKAGE_NAME)_$(VERSION)_aarch64.deb "$$PKG_URL"

sop-extract:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-extract PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "📦 SOP Step 3: Extract $(PACKAGE_NAME) package contents"
	@mkdir -p $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract
	@dpkg-deb -x $(PACKAGES_DIR)/$(PACKAGE_NAME)_*_aarch64.deb $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract/
	@echo "Extracted to: $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract/"

sop-analyze:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-analyze PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "🔍 SOP Step 4: Analyze $(PACKAGE_NAME) package structure"
	@echo ""
	@echo "Executables in /usr/bin:"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" || echo "  (none found)"
	@echo ""
	@echo "Libraries in /usr/lib:"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/lib/*" -name "*.so*" || echo "  (none found)"
	@echo ""
	@echo "File types:"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -path "*/usr/bin/*" -o -path "*/usr/lib/*.so*" -type f | while read file; do \
		echo "  $$(basename $$file): $$(file $$file | cut -d: -f2)"; \
	done 2>/dev/null || true

sop-copy:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-copy PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "📋 SOP Step 5: Copy $(PACKAGE_NAME) files to Android APK structure"
	@mkdir -p $(JNILIBS_DIR)
	@# Copy executables with lib prefix and .so extension
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | while read file; do \
		filename=$$(basename "$$file"); \
		target="$(JNILIBS_DIR)/lib$$filename.so"; \
		echo "  Copying executable: $$filename -> lib$$filename.so"; \
		cp "$$file" "$$target"; \
		chmod +x "$$target"; \
	done || true
	@# Copy libraries keeping original names
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/lib/*" -name "*.so*" | while read file; do \
		filename=$$(basename "$$file"); \
		target="$(JNILIBS_DIR)/$$filename"; \
		echo "  Copying library: $$filename"; \
		cp "$$file" "$$target"; \
		chmod +x "$$target"; \
	done || true
	@echo "Files copied to: $(JNILIBS_DIR)/"

sop-update:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-update PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "⚙️ SOP Step 6: Update TermuxInstaller.java for $(PACKAGE_NAME)"
	@# Check if there are executables that need TermuxInstaller.java updates
	@EXECUTABLES=$$(find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | wc -l | tr -d ' '); \
	if [ "$$EXECUTABLES" -gt 0 ]; then \
		echo "Found $$EXECUTABLES executable(s). Manual TermuxInstaller.java update required:"; \
		find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | while read file; do \
			filename=$$(basename "$$file"); \
			echo "  {\"lib$$filename.so\", \"$$filename\"},"; \
		done; \
		echo ""; \
		echo "Add these entries to the executables array in:"; \
		echo "  app/src/main/java/com/termux/app/TermuxInstaller.java"; \
	else \
		echo "No executables found. No TermuxInstaller.java update needed (libraries only)."; \
	fi

sop-build:
	@echo "🔨 SOP Step 7: Build and test integration"
	@$(MAKE) clean build install
	@echo "✅ Build completed. Test functionality with: make run"

