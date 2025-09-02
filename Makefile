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

.PHONY: help build release lint test clean install uninstall run logs devices abi verify-abi doctor check-jnilibs check-packages sop-help sop-list sop-download sop-extract sop-analyze sop-copy sop-update sop-build sop-add-package

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
	@echo "  check-jnilibs   - Verify all jniLibs files end with .so"
	@echo "  check-packages  - Verify all packages are valid .deb files"
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

build: check-jnilibs
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

install: uninstall build verify-abi
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

check-jnilibs:
	@echo "🔍 Checking jniLibs files for proper .so extension..."
	@JNILIBS_DIR="app/src/main/jniLibs/arm64-v8a"; \
	if [ ! -d "$$JNILIBS_DIR" ]; then \
		echo "✅ No jniLibs directory found - skipping check"; \
		exit 0; \
	fi; \
	INVALID_FILES=$$(find "$$JNILIBS_DIR" -type f ! -name "*.so" 2>/dev/null); \
	if [ -n "$$INVALID_FILES" ]; then \
		echo "❌ Found files without .so extension:"; \
		echo "$$INVALID_FILES" | while read -r file; do \
			echo "  - $$file"; \
		done; \
		echo ""; \
		echo "💡 Fix suggestions:"; \
		echo "$$INVALID_FILES" | while read -r file; do \
			basename_file=$$(basename "$$file"); \
			if [[ "$$basename_file" == *.so.* ]]; then \
				new_name=$$(echo "$$basename_file" | sed 's/\.so\.//' | sed 's/\..*/.so/'); \
				echo "  mv $$file $$(dirname "$$file")/$$new_name"; \
			else \
				echo "  mv $$file $$file.so"; \
			fi; \
		done; \
		echo ""; \
		echo "All files in jniLibs must end with .so extension for Android compatibility"; \
		exit 1; \
	else \
		echo "✅ All jniLibs files have proper .so extension"; \
	fi

check-packages:
	@echo "🔍 Checking packages directory for valid .deb files..."
	@PACKAGES_DIR="packages"; \
	if [ ! -d "$$PACKAGES_DIR" ]; then \
		echo "✅ No packages directory found - skipping check"; \
		exit 0; \
	fi; \
	DEB_FILES=$$(find "$$PACKAGES_DIR" -name "*.deb" -type f 2>/dev/null); \
	if [ -z "$$DEB_FILES" ]; then \
		echo "✅ No .deb files found in packages directory"; \
		exit 0; \
	fi; \
	INVALID_DEBS=""; \
	echo "$$DEB_FILES" | while read -r deb_file; do \
		if ! dpkg-deb --info "$$deb_file" >/dev/null 2>&1; then \
			echo "❌ Invalid .deb file: $$deb_file"; \
			INVALID_DEBS="$$INVALID_DEBS $$deb_file"; \
		else \
			package_name=$$(dpkg-deb --field "$$deb_file" Package 2>/dev/null); \
			version=$$(dpkg-deb --field "$$deb_file" Version 2>/dev/null); \
			arch=$$(dpkg-deb --field "$$deb_file" Architecture 2>/dev/null); \
			if [ "$$arch" != "aarch64" ] && [ "$$arch" != "arm64" ] && [ "$$arch" != "all" ]; then \
				echo "⚠️  Wrong architecture in $$deb_file: $$arch (expected aarch64)"; \
			else \
				echo "✅ Valid .deb: $$package_name $$version ($$arch)"; \
			fi; \
		fi; \
	done; \
	if [ -n "$$INVALID_DEBS" ]; then \
		echo ""; \
		echo "💡 Found invalid .deb files. Consider removing them:"; \
		echo "$$INVALID_DEBS" | tr ' ' '\n' | while read -r invalid_deb; do \
			if [ -n "$$invalid_deb" ]; then \
				echo "  rm $$invalid_deb"; \
			fi; \
		done; \
		exit 1; \
	fi

##
## SOP Package Integration Targets
##

# SOP Variables
PACKAGES_DIR ?= packages
JNILIBS_DIR ?= app/src/main/jniLibs/arm64-v8a
ASSETS_DIR ?= app/src/main/assets/termux
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
	@echo "File types (determines integration method):"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -path "*/usr/bin/*" -type f | while read file; do \
		filetype=$$(file "$$file" | cut -d: -f2); \
		filename=$$(basename "$$file"); \
		if echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			echo "  $$filename: $$filetype → NATIVE (jniLibs)"; \
		else \
			echo "  $$filename: $$filetype → SCRIPT (assets)"; \
		fi; \
	done 2>/dev/null || true

sop-copy:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-copy PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "📋 SOP Step 5: Copy $(PACKAGE_NAME) files to Android APK structure"
	@mkdir -p $(JNILIBS_DIR)
	@mkdir -p $(ASSETS_DIR)/usr/bin
	@mkdir -p $(ASSETS_DIR)/usr/lib
	@# Copy files based on type (native vs script)
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | while read file; do \
		filename=$$(basename "$$file"); \
		filetype=$$(file "$$file" | cut -d: -f2); \
		if echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			target="$(JNILIBS_DIR)/lib$$filename.so"; \
			echo "  NATIVE: $$filename -> lib$$filename.so (jniLibs)"; \
			cp "$$file" "$$target"; \
			chmod +x "$$target"; \
		else \
			target="$(ASSETS_DIR)/usr/bin/$$filename"; \
			echo "  SCRIPT: $$filename -> assets/termux/usr/bin/$$filename"; \
			cp "$$file" "$$target"; \
			chmod +x "$$target"; \
		fi; \
	done 2>/dev/null || true
	@# Copy shared libraries keeping original names
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/lib/*" -name "*.so*" | while read file; do \
		filename=$$(basename "$$file"); \
		target="$(JNILIBS_DIR)/$$filename"; \
		echo "  LIBRARY: $$filename -> jniLibs/"; \
		cp "$$file" "$$target"; \
		chmod +x "$$target"; \
	done || true
	@# Copy supporting directories for scripts (like node_modules)
	@if [ -d "$(PACKAGES_DIR)/$(PACKAGE_NAME)-extract/data/data/com.termux/files/usr/lib/node_modules" ]; then \
		echo "  DEPENDENCIES: node_modules -> assets/termux/usr/lib/"; \
		cp -r "$(PACKAGES_DIR)/$(PACKAGE_NAME)-extract/data/data/com.termux/files/usr/lib/node_modules" \
		      "$(ASSETS_DIR)/usr/lib/"; \
	fi
	@echo "Files copied to jniLibs and assets based on type"
	@echo "🔍 Verifying jniLibs naming compliance..."
	@$(MAKE) check-jnilibs

sop-update:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-update PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "⚙️ SOP Step 6: Update TermuxInstaller.java for $(PACKAGE_NAME)"
	@# Check for native executables that need TermuxInstaller.java updates
	@NATIVE_COUNT=0; \
	SCRIPT_COUNT=0; \
	find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | while read file; do \
		filetype=$$(file "$$file" | cut -d: -f2); \
		if echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			NATIVE_COUNT=$$((NATIVE_COUNT + 1)); \
		else \
			SCRIPT_COUNT=$$((SCRIPT_COUNT + 1)); \
		fi; \
	done 2>/dev/null; \
	echo "Analysis: Found native and script executables"; \
	echo ""; \
	echo "NATIVE executables (require TermuxInstaller.java entries):"; \
	find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | while read file; do \
		filename=$$(basename "$$file"); \
		filetype=$$(file "$$file" | cut -d: -f2); \
		if echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			echo "  {\"lib$$filename.so\", \"$$filename\"},"; \
		fi; \
	done 2>/dev/null || true; \
	echo ""; \
	echo "SCRIPT files (handled automatically by asset extraction):"; \
	find $(PACKAGES_DIR)/$(PACKAGE_NAME)-extract -type f -path "*/usr/bin/*" | while read file; do \
		filename=$$(basename "$$file"); \
		filetype=$$(file "$$file" | cut -d: -f2); \
		if ! echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			echo "  $$filename (no TermuxInstaller.java entry needed)"; \
		fi; \
	done 2>/dev/null || true; \
	echo ""; \
	echo "Add ONLY the native executable entries to:"; \
	echo "  app/src/main/java/com/termux/app/TermuxInstaller.java"

sop-build:
	@echo "🔨 SOP Step 7: Build and test integration"
	@$(MAKE) check-packages clean build install
	@echo "✅ Build completed. Test functionality with: make run"

