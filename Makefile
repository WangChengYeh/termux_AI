## Make targets to build, test, and install Termux AI (aarch64-only)

# Configurable variables
GRADLEW ?= ./gradlew
MODULE ?= app
BUILD_TYPE ?= debug # debug|release
APP_ID ?= com.termux
MAIN_ACTIVITY ?= com.termux.app.TermuxActivity

# Release variables
RELEASE_VERSION ?= $(shell date +v%Y.%m.%d)
RELEASE_TITLE ?= Termux AI $(RELEASE_VERSION) - Node.js Integration Release
RELEASE_DRAFT ?= false
RELEASE_PRERELEASE ?= false

# Derived values - Use correct APK filenames based on build type
ifeq ($(strip $(BUILD_TYPE)),debug)
APK_DIR := $(MODULE)/build/outputs/apk/debug
APK_BASENAME := termux-app_apt-android-7-debug_arm64-v8a.apk
else
APK_DIR := $(MODULE)/build/outputs/apk/release
APK_BASENAME := termux-app_apt-android-7-release_universal.apk
endif
APK := $(APK_DIR)/$(APK_BASENAME)

.PHONY: help build release lint test clean install uninstall run logs devices abi verify-abi doctor grant-permissions check-jnilibs check-packages check-duplicates sop-help sop-list sop-download sop-extract sop-analyze sop-copy sop-update sop-build sop-test sop-user-test sop-ldd-test sop-add-package sop-check sop-check-all github-release github-release-notes github-auth-check github-tag-version

help:
	@echo "Termux AI Makefile (aarch64-only)"
	@echo "Available targets:"
	@echo "  build           - Assemble $(BUILD_TYPE) APK"
	@echo "  release         - Assemble release APK"
	@echo "  lint            - Run Android Lint for :$(MODULE)"
	@echo "  test            - Run unit tests"
	@echo "  clean           - Clean Gradle build outputs"
	@echo "  install         - Install built APK via adb (-r) with permissions"
	@echo "  uninstall       - Uninstall $(APP_ID) via adb"
	@echo "  grant-permissions - Grant essential permissions to installed app"
	@echo "  run             - Launch $(MAIN_ACTIVITY) on device"
	@echo "  logs            - Tail logcat for $(APP_ID)"
	@echo "  devices         - List adb devices"
	@echo "  abi             - Show device ABI"
	@echo "  verify-abi      - Ensure connected device is arm64-v8a"
	@echo "  check-jnilibs   - Verify all jniLibs files end with .so"
	@echo "  check-packages  - Verify all packages are valid .deb files"
	@echo "  check-duplicates- Find and report duplicate files in jniLibs"
	@echo ""
	@echo "GitHub Release Management:"
	@echo "  github-release-script     - Enhanced release script with auto-versioning"
	@echo "  github-release-script-dry-run - Build APK without creating release"
	@echo "  github-release  - Create GitHub release with APK upload"
	@echo "  github-tag-version - Create and push version tag"
	@echo "  github-auth-check - Verify GitHub CLI authentication"
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
	@echo "  sop-test        - Interactive command testing in live app"
	@echo "  sop-user-test   - Automated UI testing via ADB input, creates sop-test-latest.log"
	@echo "  sop-ldd-test    - Test executables with ldd for missing libraries"
	@echo "  sop-check       - Compare package files between host and device"
	@echo "  sop-check-all   - Check all packages (auto-extracts .deb files if needed)"
	@echo ""
	@echo "Variables: BUILD_TYPE=debug|release, MODULE=$(MODULE), APP_ID=$(APP_ID)"
	@echo "SOP Variables: PACKAGE_NAME, VERSION, LETTER (for browsing)"
	@echo "Release Variables: RELEASE_VERSION, RELEASE_TITLE, RELEASE_DRAFT, RELEASE_PRERELEASE"

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
	@echo "🔐 Granting essential permissions..."
	@# Grant storage permissions for file access
	adb shell pm grant "$(APP_ID)" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true
	adb shell pm grant "$(APP_ID)" android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true
	@# Grant notification permission for foreground service (Android 13+)
	adb shell pm grant "$(APP_ID)" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
	@# Disable battery optimization to prevent service termination
	adb shell dumpsys deviceidle whitelist +"$(APP_ID)" 2>/dev/null || true
	@# Grant system overlay permission for terminal window
	adb shell appops set "$(APP_ID)" SYSTEM_ALERT_WINDOW allow 2>/dev/null || true
	@# Grant usage stats for package management features
	adb shell appops set "$(APP_ID)" GET_USAGE_STATS allow 2>/dev/null || true
	@echo "✅ Installation completed with permissions granted"

uninstall:
	adb uninstall "$(APP_ID)" || true

grant-permissions:
	@echo "🔐 Granting essential permissions to $(APP_ID)..."
	@# Grant storage permissions for file access
	adb shell pm grant "$(APP_ID)" android.permission.READ_EXTERNAL_STORAGE 2>/dev/null || true
	adb shell pm grant "$(APP_ID)" android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null || true
	@# Grant notification permission for foreground service (Android 13+)
	adb shell pm grant "$(APP_ID)" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
	@# Disable battery optimization to prevent service termination
	adb shell dumpsys deviceidle whitelist +"$(APP_ID)" 2>/dev/null || true
	@# Grant system overlay permission for terminal window
	adb shell appops set "$(APP_ID)" SYSTEM_ALERT_WINDOW allow 2>/dev/null || true
	@# Grant usage stats for package management features
	adb shell appops set "$(APP_ID)" GET_USAGE_STATS allow 2>/dev/null || true
	@echo "✅ Essential permissions granted to $(APP_ID)"

run:
	@echo "🚀 Launching Termux AI..."
	@adb shell am start -W -S -n "$(APP_ID)/.app.TermuxActivity" | grep -E "(Status|TotalTime)" || true
	@echo "✅ App launched"

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

check-duplicates:
	@echo "🔍 Checking for duplicate files in jniLibs..."
	@JNILIBS_DIR="app/src/main/jniLibs/arm64-v8a"; \
	if [ ! -d "$$JNILIBS_DIR" ]; then \
		echo "✅ No jniLibs directory found - skipping check"; \
		exit 0; \
	fi; \
	echo "📊 Analyzing files by size and content..."; \
	echo ""; \
	DUPLICATES_FOUND=0; \
	TEMP_FILE=$$(mktemp); \
	find "$$JNILIBS_DIR" -name "*.so" -type f -exec ls -l {} \; | \
		awk '{print $$5, $$9}' | sort -n > "$$TEMP_FILE"; \
	PREV_SIZE=""; \
	SAME_SIZE_FILES=""; \
	while read -r SIZE FILE; do \
		if [ "$$SIZE" = "$$PREV_SIZE" ]; then \
			SAME_SIZE_FILES="$$SAME_SIZE_FILES $$FILE"; \
		else \
			if [ -n "$$SAME_SIZE_FILES" ] && [ $$(echo "$$SAME_SIZE_FILES" | wc -w) -gt 1 ]; then \
				FIRST_FILE=$$(echo "$$SAME_SIZE_FILES" | awk '{print $$1}'); \
				DUPLICATES=""; \
				for FILE in $$SAME_SIZE_FILES; do \
					if [ "$$FILE" != "$$FIRST_FILE" ]; then \
						if cmp -s "$$FIRST_FILE" "$$FILE"; then \
							DUPLICATES="$$DUPLICATES $$FILE"; \
						fi; \
					fi; \
				done; \
				if [ -n "$$DUPLICATES" ]; then \
					echo "🔁 Duplicate set found (size: $$PREV_SIZE bytes):"; \
					echo "  📌 Source: $$(basename $$FIRST_FILE)"; \
					for DUP in $$DUPLICATES; do \
						echo "  ↳ Duplicate: $$(basename $$DUP)"; \
					done; \
					echo ""; \
					DUPLICATES_FOUND=1; \
				fi; \
			fi; \
			SAME_SIZE_FILES="$$FILE"; \
			PREV_SIZE="$$SIZE"; \
		fi; \
	done < "$$TEMP_FILE"; \
	if [ -n "$$SAME_SIZE_FILES" ] && [ $$(echo "$$SAME_SIZE_FILES" | wc -w) -gt 1 ]; then \
		FIRST_FILE=$$(echo "$$SAME_SIZE_FILES" | awk '{print $$1}'); \
		DUPLICATES=""; \
		for FILE in $$SAME_SIZE_FILES; do \
			if [ "$$FILE" != "$$FIRST_FILE" ]; then \
				if cmp -s "$$FIRST_FILE" "$$FILE"; then \
					DUPLICATES="$$DUPLICATES $$FILE"; \
				fi; \
			fi; \
		done; \
		if [ -n "$$DUPLICATES" ]; then \
			echo "🔁 Duplicate set found (size: $$PREV_SIZE bytes):"; \
			echo "  📌 Source: $$(basename $$FIRST_FILE)"; \
			for DUP in $$DUPLICATES; do \
				echo "  ↳ Duplicate: $$(basename $$DUP)"; \
			done; \
			echo ""; \
			DUPLICATES_FOUND=1; \
		fi; \
	fi; \
	rm -f "$$TEMP_FILE"; \
	if [ "$$DUPLICATES_FOUND" -eq 1 ]; then \
		echo "💡 Recommendation: Use symbolic links in TermuxInstaller.java to map duplicates to single source"; \
		echo "   This saves APK size by avoiding redundant binary storage"; \
		echo ""; \
		echo "Example TermuxInstaller.java mapping:"; \
		echo '  {"libz1.so", "z"},'; \
		echo '  {"libz1.so", "zlib"},  // Symlink to same source'; \
		echo '  {"libz1.so", "z131"},  // Symlink to same source'; \
	else \
		echo "✅ No duplicate files found in jniLibs"; \
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
	@echo "  make sop-extract PACKAGE_NAME=nodejs      # Extract to packages/xxx-complete/ (data + control)"
	@echo "  make sop-analyze PACKAGE_NAME=nodejs"
	@echo "  make sop-copy PACKAGE_NAME=nodejs"
	@echo "  make sop-update PACKAGE_NAME=nodejs      # Updates TermuxInstaller.java if needed"
	@echo "  make sop-build                           # Build and test integration"
	@echo ""
	@echo "Dependency Resolution:"
	@echo "  make sop-get-contents                    # Download Contents-aarch64 if missing"
	@echo "  make sop-find-lib LIBRARY=libcharset.so  # Find package containing library"
	@echo "  make sop-add-deps PACKAGE_NAME=git       # Auto-resolve and add dependencies"
	@echo ""
	@echo "Package Analysis:"
	@echo "  make extract-package PACKAGE_NAME=libgmp # Alias for sop-extract (data + control)"
	@echo ""
	@echo "Examples:"
	@echo "  make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1"
	@echo "  make sop-add-package PACKAGE_NAME=nano VERSION=8.2"
	@echo "  make sop-list LETTER=liba                # List lib* packages"
	@echo "  make extract-package PACKAGE_NAME=coreutils  # Analyze coreutils package"

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
	@if echo "$(PACKAGE_NAME)" | grep -q "^lib"; then \
		URL_PATH=$$(echo "$(PACKAGE_NAME)" | cut -c1-4); \
		PKG_URL="https://packages.termux.dev/apt/termux-main/pool/main/$$URL_PATH/$(PACKAGE_NAME)/$(PACKAGE_NAME)_$(VERSION)_aarch64.deb"; \
	else \
		URL_PATH=$$(echo "$(PACKAGE_NAME)" | cut -c1); \
		PKG_URL="https://packages.termux.dev/apt/termux-main/pool/main/$$URL_PATH/$(PACKAGE_NAME)/$(PACKAGE_NAME)_$(VERSION)_aarch64.deb"; \
	fi; \
	echo "Downloading from: $$PKG_URL"; \
	wget -O $(PACKAGES_DIR)/$(PACKAGE_NAME)_$(VERSION)_aarch64.deb "$$PKG_URL"

sop-extract:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-extract PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "📦 SOP Step 3: Extract $(PACKAGE_NAME) package contents (data + control)"
	@EXTRACT_DIR="$(PACKAGES_DIR)/$(PACKAGE_NAME)-complete"; \
	DEB_FILE=$$(ls $(PACKAGES_DIR)/$(PACKAGE_NAME)_*_aarch64.deb | head -1); \
	if [ ! -f "$$DEB_FILE" ]; then \
		echo "❌ Package file not found: $(PACKAGES_DIR)/$(PACKAGE_NAME)_*_aarch64.deb"; \
		exit 1; \
	fi; \
	echo "🔍 Using package file: $$DEB_FILE"; \
	rm -rf "$$EXTRACT_DIR"; \
	mkdir -p "$$EXTRACT_DIR"; \
	echo "🔧 Extracting control files..."; \
	dpkg-deb --control "$$DEB_FILE" "$$EXTRACT_DIR/control"; \
	echo "🔧 Extracting data files..."; \
	dpkg-deb --extract "$$DEB_FILE" "$$EXTRACT_DIR/data"; \
	echo "✅ Complete extraction to: $$EXTRACT_DIR/"

sop-analyze:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-analyze PACKAGE_NAME=nodejs"; \
		exit 1; \
	fi
	@echo "🔍 SOP Step 4: Analyze $(PACKAGE_NAME) package structure"
	@echo ""
	@echo "📋 Package Information:"
	@echo "======================"
	@cat $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/control/control 2>/dev/null || echo "  (no control file found)"
	@echo ""
	@echo "Executables in /usr/bin:"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/bin/*" 2>/dev/null || echo "  (none found)"
	@echo ""
	@echo "Libraries in /usr/lib:"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/lib/*" -name "*.so*" 2>/dev/null || echo "  (none found)"
	@echo ""
	@echo "File types (determines integration method):"
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -path "*/usr/bin/*" -type f 2>/dev/null | while read file; do \
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
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/bin/*" 2>/dev/null | while read file; do \
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
	@find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/lib/*" -name "*.so*" 2>/dev/null | while read file; do \
		filename=$$(basename "$$file"); \
		target="$(JNILIBS_DIR)/$$filename"; \
		echo "  LIBRARY: $$filename -> jniLibs/"; \
		cp "$$file" "$$target"; \
		chmod +x "$$target"; \
	done || true
	@# Copy supporting directories for scripts (like node_modules)
	@if [ -d "$(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data/data/com.termux/files/usr/lib/node_modules" ]; then \
		echo "  DEPENDENCIES: node_modules -> assets/termux/usr/lib/"; \
		cp -r "$(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data/data/com.termux/files/usr/lib/node_modules" \
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
	find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/bin/*" 2>/dev/null | while read file; do \
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
	find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/bin/*" 2>/dev/null | while read file; do \
		filename=$$(basename "$$file"); \
		filetype=$$(file "$$file" | cut -d: -f2); \
		if echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			echo "  {\"lib$$filename.so\", \"$$filename\"},"; \
		fi; \
	done 2>/dev/null || true; \
	echo ""; \
	echo "SCRIPT files (handled automatically by asset extraction):"; \
	find $(PACKAGES_DIR)/$(PACKAGE_NAME)-complete/data -type f -path "*/usr/bin/*" 2>/dev/null | while read file; do \
		filename=$$(basename "$$file"); \
		filetype=$$(file "$$file" | cut -d: -f2); \
		if ! echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
			echo "  $$filename (no TermuxInstaller.java entry needed)"; \
		fi; \
	done 2>/dev/null || true; \
	echo ""; \
	echo "Add ONLY the native executable entries to:"; \
	echo "  app/src/main/java/com/termux/app/TermuxInstaller.java"

# Extract complete package including both data and control files
extract-package:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "❌ Error: PACKAGE_NAME is required"; \
		echo "Usage: make extract-package PACKAGE_NAME=libgmp"; \
		exit 1; \
	fi
	@echo "📦 Extracting complete package: $(PACKAGE_NAME)"
	@PACKAGE_FILE=$$(find $(PACKAGES_DIR) -name "$(PACKAGE_NAME)_*.deb" | head -1); \
	if [ -z "$$PACKAGE_FILE" ]; then \
		echo "❌ Package file not found for $(PACKAGE_NAME)"; \
		echo "Available packages:"; \
		ls $(PACKAGES_DIR)/*.deb 2>/dev/null | xargs -n1 basename || true; \
		exit 1; \
	fi; \
	EXTRACT_DIR="$(PACKAGES_DIR)/$(PACKAGE_NAME)-complete"; \
	echo "📂 Extracting to: $$EXTRACT_DIR"; \
	rm -rf "$$EXTRACT_DIR"; \
	mkdir -p "$$EXTRACT_DIR"; \
	echo "🔧 Extracting control files..."; \
	dpkg-deb --control "$$PACKAGE_FILE" "$$EXTRACT_DIR/control"; \
	echo "🔧 Extracting data files..."; \
	dpkg-deb --extract "$$PACKAGE_FILE" "$$EXTRACT_DIR/data"; \
	echo "📋 Package Information:"; \
	echo "===================="; \
	cat "$$EXTRACT_DIR/control/control" 2>/dev/null || echo "No control file found"; \
	echo ""; \
	echo "📁 Data Structure:"; \
	echo "=================="; \
	find "$$EXTRACT_DIR/data" -type f | head -20 | while read file; do \
		rel_path=$${file#$$EXTRACT_DIR/data/}; \
		file_info=$$(file "$$file" 2>/dev/null | cut -d: -f2 | sed 's/^[[:space:]]*//'); \
		echo "$$rel_path: $$file_info"; \
	done; \
	total_files=$$(find "$$EXTRACT_DIR/data" -type f | wc -l); \
	if [ $$total_files -gt 20 ]; then \
		echo "... and $$((total_files - 20)) more files"; \
	fi; \
	echo ""; \
	echo "✅ Complete extraction finished: $$EXTRACT_DIR"

sop-build:
	@echo "🔨 SOP Step 7: Build and test integration"
	@$(MAKE) check-packages clean build install
	@echo "✅ Build completed. Test functionality with: make run"

sop-test:
	@echo "🧪 SOP Interactive Testing: Type commands directly into the app"
	@echo ""
	@echo "This will:"
	@echo "  1. Launch Termux AI app if not running"
	@echo "  2. Open ADB shell to the app"
	@echo "  3. Allow you to test commands interactively"
	@echo ""
	@echo "📱 Launching Termux AI..."
	@adb shell am start -W -S -n "$(APP_ID)/.app.TermuxActivity" >/dev/null 2>&1 || true
	@sleep 2
	@echo "🔗 Connecting to app via ADB shell..."
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "📋 Test these commands inside the app:"
	@echo "   source .profile           # Load environment (done automatically)"
	@echo "   codex --help              # Test AI CLI"
	@echo "   codex-exec --help         # Test non-interactive AI"
	@echo "   node --version            # Test Node.js runtime"
	@echo "   npm --version             # Test NPM"
	@echo "   npx --version             # Test NPX"
	@echo "   apt --version             # Test package manager"
	@echo "   ls /usr/bin               # List available commands"
	@echo "   ls -la /usr/lib           # List available libraries"
	@echo "   file /usr/bin/node        # Check if symlinks work"
	@echo "   ldd /usr/bin/node         # Check library dependencies"
	@echo "   echo \$$PATH               # Verify PATH environment"
	@echo "   pwd                       # Check current directory"
	@echo "   whoami                    # Check user context"
	@echo "   exit                      # Exit when done testing"
	@echo "═══════════════════════════════════════════════════════════════"
	@echo ""
	@echo "🚀 Starting interactive shell. Type 'exit' when done:"
	@adb shell "run-as $(APP_ID) /system/bin/sh -c 'cd /data/data/$(APP_ID)/files/home && source /data/data/$(APP_ID)/files/home/.profile && /system/bin/sh'" || \
	echo "❌ Could not connect to app. Make sure the app is installed and running."

sop-user-test:
	@APP_ID="$(APP_ID)" MAIN_ACTIVITY="$(MAIN_ACTIVITY)" ./scripts/sop-user-test.sh

sop-ldd-test:
	@if [ -n "$(EXECUTABLE)" ]; then \
		APP_ID="$(APP_ID)" MAIN_ACTIVITY="$(MAIN_ACTIVITY)" ./scripts/sop-ldd-test.sh "$(EXECUTABLE)"; \
	else \
		APP_ID="$(APP_ID)" MAIN_ACTIVITY="$(MAIN_ACTIVITY)" ./scripts/sop-ldd-test.sh; \
	fi

sop-check:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "Usage: make sop-check PACKAGE_NAME=nodejs"; \
		echo "       make sop-check PACKAGE_NAME=readline"; \
		echo ""; \
		echo "This compares files from the extracted .deb package with files"; \
		echo "actually accessible in the running Termux AI app."; \
		exit 1; \
	fi
	@echo "🔍 SOP Checker: Comparing $(PACKAGE_NAME) files between host and device"
	@echo "============================================================================"
	@echo ""
	@# Check if package is extracted
	@EXTRACT_DIR="$(PACKAGES_DIR)/$(PACKAGE_NAME)-complete"; \
	if [ ! -d "$$EXTRACT_DIR" ]; then \
		echo "❌ Package $(PACKAGE_NAME) not extracted yet"; \
		echo "Run: make sop-extract PACKAGE_NAME=$(PACKAGE_NAME)"; \
		exit 1; \
	fi; \
	echo "📦 Host Package Analysis"; \
	echo "========================"; \
	echo ""; \
	echo "🔧 Executables in /usr/bin:"; \
	HOST_BINS=$$(find "$$EXTRACT_DIR/data" \( -type f -o -type l \) -path "*/usr/bin/*" 2>/dev/null); \
	if [ -n "$$HOST_BINS" ]; then \
		echo "$$HOST_BINS" | while read -r file; do \
			filename=$$(basename "$$file"); \
			if [ -L "$$file" ]; then \
				echo "  📜 $$filename (SYMLINK) - Expected in /usr/bin/ via assets"; \
			else \
				filetype=$$(file "$$file" | cut -d: -f2 | sed 's/^[[:space:]]*//'); \
				if echo "$$filetype" | grep -q "ELF.*ARM aarch64"; then \
					echo "  📄 $$filename (NATIVE) - Expected in /usr/bin/ via jniLibs"; \
				else \
					echo "  📜 $$filename (SCRIPT) - Expected in /usr/bin/ via assets"; \
				fi; \
			fi; \
		done; \
	else \
		echo "  (none found)"; \
	fi; \
	echo ""; \
	echo "📚 Libraries in /usr/lib:"; \
	HOST_LIBS=$$(find "$$EXTRACT_DIR/data" \( -type f -o -type l \) -path "*/usr/lib/*" -name "*.so*" 2>/dev/null); \
	if [ -n "$$HOST_LIBS" ]; then \
		echo "$$HOST_LIBS" | while read -r file; do \
			filename=$$(basename "$$file"); \
			echo "  🔗 $$filename - Expected in /usr/lib/ via jniLibs"; \
		done; \
	else \
		echo "  (none found)"; \
	fi; \
	echo ""; \
	echo "📱 Device Verification"; \
	echo "====================="; \
	echo ""; \
	echo "🔌 Testing device connection..."; \
	if ! adb shell run-as $(APP_ID) echo "Connected" >/dev/null 2>&1; then \
		echo "❌ Cannot connect to device or app not installed"; \
		echo "Ensure Termux AI is installed and run: make install run"; \
		exit 1; \
	fi; \
	echo "✅ Device connected, app accessible"; \
	echo ""; \
	echo "🔧 Checking executables on device:"; \
	if [ -n "$$HOST_BINS" ]; then \
		echo "$$HOST_BINS" | while read -r file; do \
			filename=$$(basename "$$file"); \
			DEVICE_BIN="/data/data/$(APP_ID)/files/usr/bin/$$filename"; \
			if adb shell run-as $(APP_ID) test -f "$$DEVICE_BIN" 2>/dev/null; then \
				if adb shell run-as $(APP_ID) test -x "$$DEVICE_BIN" 2>/dev/null; then \
					TARGET=$$(adb shell run-as $(APP_ID) readlink "$$DEVICE_BIN" 2>/dev/null | tr -d '\r' || echo "not-a-link"); \
					if [ "$$TARGET" = "not-a-link" ]; then \
						echo "  ✅ $$filename - EXISTS (regular file)"; \
					else \
						echo "  ✅ $$filename - EXISTS (symlink → $$TARGET)"; \
					fi; \
				else \
					echo "  ⚠️  $$filename - EXISTS but not executable"; \
				fi; \
			else \
				echo "  ❌ $$filename - MISSING"; \
			fi; \
		done; \
	fi; \
	echo ""; \
	echo "📚 Checking libraries on device:"; \
	if [ -n "$$HOST_LIBS" ]; then \
		echo "$$HOST_LIBS" | while read -r file; do \
			filename=$$(basename "$$file"); \
			DEVICE_LIB="/data/data/$(APP_ID)/files/usr/lib/$$filename"; \
			if adb shell run-as $(APP_ID) test -f "$$DEVICE_LIB" 2>/dev/null; then \
				TARGET=$$(adb shell run-as $(APP_ID) readlink "$$DEVICE_LIB" 2>/dev/null | tr -d '\r' || echo "not-a-link"); \
				if [ "$$TARGET" = "not-a-link" ]; then \
					echo "  ✅ $$filename - EXISTS (regular file)"; \
				else \
					echo "  ✅ $$filename - EXISTS (symlink → $$TARGET)"; \
				fi; \
			else \
				echo "  ❌ $$filename - MISSING"; \
			fi; \
		done; \
	fi; \
	echo ""; \
	echo "🧪 Functional Testing"; \
	echo "====================="; \
	echo ""; \
	if [ -n "$$HOST_BINS" ]; then \
		echo "$$HOST_BINS" | head -3 | while read -r file; do \
			filename=$$(basename "$$file"); \
			echo "🔧 Testing $$filename execution:"; \
			DEVICE_BIN="/data/data/$(APP_ID)/files/usr/bin/$$filename"; \
			if adb shell run-as $(APP_ID) test -x "$$DEVICE_BIN" 2>/dev/null; then \
				if [ "$$filename" = "bash" ] || [ "$$filename" = "sh" ]; then \
					RESULT=$$(adb shell run-as $(APP_ID) "$$DEVICE_BIN" --version 2>&1 | head -1 | tr -d '\r' || echo "failed"); \
				elif [ "$$filename" = "node" ]; then \
					RESULT=$$(adb shell run-as $(APP_ID) "$$DEVICE_BIN" --version 2>&1 | tr -d '\r' || echo "failed"); \
				elif [ "$$filename" = "vim" ]; then \
					RESULT=$$(adb shell run-as $(APP_ID) "$$DEVICE_BIN" --version 2>&1 | head -1 | tr -d '\r' || echo "failed"); \
				else \
					RESULT=$$(adb shell run-as $(APP_ID) "$$DEVICE_BIN" --version 2>&1 | head -1 | tr -d '\r' || echo "version-failed"); \
					if [ "$$RESULT" = "version-failed" ]; then \
						RESULT=$$(adb shell run-as $(APP_ID) "$$DEVICE_BIN" --help 2>&1 | head -1 | tr -d '\r' || echo "help-failed"); \
						if [ "$$RESULT" = "help-failed" ]; then \
							RESULT=$$(adb shell run-as $(APP_ID) echo "test" | "$$DEVICE_BIN" 2>&1 >/dev/null && echo "executable" || echo "failed"); \
						fi; \
					fi; \
				fi; \
				if echo "$$RESULT" | grep -q "failed\|not found\|command not found\|CANNOT LINK"; then \
					echo "  ❌ FAILED: $$RESULT"; \
				else \
					echo "  ✅ OK: $$RESULT"; \
				fi; \
			else \
				echo "  ❌ SKIPPED: Not executable or missing"; \
			fi; \
		done; \
	fi; \
	echo ""; \
	echo "📊 Summary"; \
	echo "=========="; \
	TOTAL_FILES=0; \
	MISSING_FILES=0; \
	if [ -n "$$HOST_BINS" ]; then \
		TOTAL_FILES=$$(echo "$$HOST_BINS" | wc -l | tr -d ' '); \
		echo "$$HOST_BINS" | while read -r file; do \
			filename=$$(basename "$$file"); \
			DEVICE_BIN="/data/data/$(APP_ID)/files/usr/bin/$$filename"; \
			if ! adb shell run-as $(APP_ID) test -f "$$DEVICE_BIN" 2>/dev/null; then \
				echo "$$filename" >> /tmp/missing_files_$$$$; \
			fi; \
		done; \
		if [ -f "/tmp/missing_files_$$$$" ]; then \
			MISSING_FILES=$$(cat /tmp/missing_files_$$$$ | wc -l | tr -d ' '); \
			rm -f /tmp/missing_files_$$$$; \
		fi; \
	fi; \
	if [ -n "$$HOST_LIBS" ]; then \
		LIB_COUNT=$$(echo "$$HOST_LIBS" | wc -l | tr -d ' '); \
		TOTAL_FILES=$$((TOTAL_FILES + LIB_COUNT)); \
		echo "$$HOST_LIBS" | while read -r file; do \
			filename=$$(basename "$$file"); \
			DEVICE_LIB="/data/data/$(APP_ID)/files/usr/lib/$$filename"; \
			if ! adb shell run-as $(APP_ID) test -f "$$DEVICE_LIB" 2>/dev/null; then \
				echo "$$filename" >> /tmp/missing_libs_$$$$; \
			fi; \
		done; \
		if [ -f "/tmp/missing_libs_$$$$" ]; then \
			MISSING_LIBS=$$(cat /tmp/missing_libs_$$$$ | wc -l | tr -d ' '); \
			MISSING_FILES=$$((MISSING_FILES + MISSING_LIBS)); \
			rm -f /tmp/missing_libs_$$$$; \
		fi; \
	fi; \
	PRESENT_FILES=$$((TOTAL_FILES - MISSING_FILES)); \
	if [ $$TOTAL_FILES -eq 0 ]; then \
		echo "📄 No files found in $(PACKAGE_NAME) package"; \
	elif [ $$MISSING_FILES -eq 0 ]; then \
		echo "✅ All $$TOTAL_FILES files from $(PACKAGE_NAME) are present and accessible"; \
	else \
		echo "⚠️  $$PRESENT_FILES/$$TOTAL_FILES files present ($$MISSING_FILES missing)"; \
		echo ""; \
		echo "💡 Troubleshooting:"; \
		echo "  1. Ensure the app has been launched: make run"; \
		echo "  2. Check TermuxInstaller.java includes native executables"; \
		echo "  3. Verify assets are properly copied for scripts"; \
		echo "  4. Check library dependencies: make sop-add-deps PACKAGE_NAME=$(PACKAGE_NAME)"; \
	fi; \
	echo ""; \
	echo "============================================================================"

sop-check-all:
	@echo "🔍 SOP Checker: Checking all packages (auto-extracting if needed)"
	@echo "================================================================"
	@echo ""
	@# Find all .deb packages first
	@ALL_DEB_PACKAGES=$$(find $(PACKAGES_DIR) -maxdepth 1 -name "*.deb" -type f 2>/dev/null | while read deb; do \
		basename "$$deb" | sed 's/_.*\.deb$$//' | sed 's/-[0-9].*//'; \
	done | sort -u); \
	if [ -z "$$ALL_DEB_PACKAGES" ]; then \
		echo "❌ No .deb packages found in $(PACKAGES_DIR)/"; \
		echo "Download packages first using: make sop-download PACKAGE_NAME=<name> VERSION=<version>"; \
		exit 1; \
	fi; \
	echo "📦 Found .deb packages for:"; \
	echo "$$ALL_DEB_PACKAGES" | while read pkg; do \
		DEB_FILE=$$(find $(PACKAGES_DIR) -name "$$pkg*.deb" | head -1); \
		if [ -n "$$DEB_FILE" ]; then \
			VERSION=$$(basename "$$DEB_FILE" | sed "s/^$$pkg_//" | sed 's/_aarch64\.deb$$//' | sed 's/_all\.deb$$//'); \
			echo "  - $$pkg ($$VERSION)"; \
		fi; \
	done; \
	echo ""; \
	PACKAGES_TO_CHECK=""; \
	echo "🔧 Checking extraction status and auto-extracting..."; \
	echo "$$ALL_DEB_PACKAGES" | while read PACKAGE; do \
		if [ -n "$$PACKAGE" ]; then \
			EXTRACT_DIR="$(PACKAGES_DIR)/$$PACKAGE-complete"; \
			if [ ! -d "$$EXTRACT_DIR" ]; then \
				echo "  📦 Extracting $$PACKAGE..."; \
				DEB_FILE=$$(find $(PACKAGES_DIR) -name "$$PACKAGE*.deb" | head -1); \
				if [ -n "$$DEB_FILE" ]; then \
					rm -rf "$$EXTRACT_DIR"; \
					mkdir -p "$$EXTRACT_DIR"; \
					dpkg-deb --control "$$DEB_FILE" "$$EXTRACT_DIR/control" 2>/dev/null; \
					dpkg-deb --extract "$$DEB_FILE" "$$EXTRACT_DIR/data" 2>/dev/null; \
					if [ -d "$$EXTRACT_DIR/data" ]; then \
						echo "    ✅ Extracted $$PACKAGE"; \
					else \
						echo "    ❌ Failed to extract $$PACKAGE"; \
						continue; \
					fi; \
				else \
					echo "    ❌ No .deb file found for $$PACKAGE"; \
					continue; \
				fi; \
			else \
				echo "  ✅ Already extracted: $$PACKAGE"; \
			fi; \
			echo "$$PACKAGE" >> /tmp/packages_to_check; \
		fi; \
	done; \
	PACKAGES_TO_CHECK=$$(cat /tmp/packages_to_check 2>/dev/null || echo ""); \
	rm -f /tmp/packages_to_check; \
	if [ -z "$$PACKAGES_TO_CHECK" ]; then \
		echo "❌ No packages available for checking"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "🔌 Testing device connection..."; \
	if ! adb shell run-as $(APP_ID) echo "Connected" >/dev/null 2>&1; then \
		echo "❌ Cannot connect to device or app not installed"; \
		echo "Ensure Termux AI is installed and run: make install run"; \
		exit 1; \
	fi; \
	echo "✅ Device connected, app accessible"; \
	echo ""; \
	echo "📊 Batch Package Check Results"; \
	echo "=============================="; \
	echo ""; \
	TOTAL_PACKAGES=0; \
	PASSED_PACKAGES=0; \
	FAILED_PACKAGES=0; \
	echo "$$PACKAGES_TO_CHECK" | while read PACKAGE; do \
		if [ -n "$$PACKAGE" ]; then \
			echo "🔍 Checking $$PACKAGE..."; \
			EXTRACT_DIR="$(PACKAGES_DIR)/$$PACKAGE-complete"; \
			HOST_BINS=$$(find "$$EXTRACT_DIR/data" \( -type f -o -type l \) -path "*/usr/bin/*" 2>/dev/null); \
			HOST_LIBS=$$(find "$$EXTRACT_DIR/data" \( -type f -o -type l \) -path "*/usr/lib/*" -name "*.so*" 2>/dev/null); \
			TOTAL_FILES=0; \
			MISSING_FILES=0; \
			if [ -n "$$HOST_BINS" ]; then \
				BIN_COUNT=$$(echo "$$HOST_BINS" | wc -l | tr -d ' '); \
				TOTAL_FILES=$$((TOTAL_FILES + BIN_COUNT)); \
				echo "$$HOST_BINS" | while read -r file; do \
					filename=$$(basename "$$file"); \
					DEVICE_BIN="/data/data/$(APP_ID)/files/usr/bin/$$filename"; \
					if ! adb shell run-as $(APP_ID) test -f "$$DEVICE_BIN" 2>/dev/null; then \
						echo "$$filename" >> /tmp/missing_bins_$$PACKAGE; \
					fi; \
				done; \
				if [ -f "/tmp/missing_bins_$$PACKAGE" ]; then \
					MISSING_BINS=$$(cat /tmp/missing_bins_$$PACKAGE | wc -l | tr -d ' '); \
					MISSING_FILES=$$((MISSING_FILES + MISSING_BINS)); \
					rm -f /tmp/missing_bins_$$PACKAGE; \
				fi; \
			fi; \
			if [ -n "$$HOST_LIBS" ]; then \
				LIB_COUNT=$$(echo "$$HOST_LIBS" | wc -l | tr -d ' '); \
				TOTAL_FILES=$$((TOTAL_FILES + LIB_COUNT)); \
				echo "$$HOST_LIBS" | while read -r file; do \
					filename=$$(basename "$$file"); \
					DEVICE_LIB="/data/data/$(APP_ID)/files/usr/lib/$$filename"; \
					if ! adb shell run-as $(APP_ID) test -f "$$DEVICE_LIB" 2>/dev/null; then \
						echo "$$filename" >> /tmp/missing_libs_$$PACKAGE; \
					fi; \
				done; \
				if [ -f "/tmp/missing_libs_$$PACKAGE" ]; then \
					MISSING_LIBS=$$(cat /tmp/missing_libs_$$PACKAGE | wc -l | tr -d ' '); \
					MISSING_FILES=$$((MISSING_FILES + MISSING_LIBS)); \
					rm -f /tmp/missing_libs_$$PACKAGE; \
				fi; \
			fi; \
			PRESENT_FILES=$$((TOTAL_FILES - MISSING_FILES)); \
			if [ $$TOTAL_FILES -eq 0 ]; then \
				echo "  📄 No files found - SKIPPED"; \
			elif [ $$MISSING_FILES -eq 0 ]; then \
				echo "  ✅ PASSED: All $$TOTAL_FILES files present"; \
				echo "1" >> /tmp/passed_packages; \
			else \
				echo "  ❌ FAILED: $$PRESENT_FILES/$$TOTAL_FILES files present ($$MISSING_FILES missing)"; \
				echo "1" >> /tmp/failed_packages; \
			fi; \
			echo "1" >> /tmp/total_packages; \
		fi; \
	done; \
	echo ""; \
	echo "📈 Final Summary"; \
	echo "================"; \
	TOTAL_COUNT=$$(cat /tmp/total_packages 2>/dev/null | wc -l | tr -d ' ' || echo "0"); \
	PASSED_COUNT=$$(cat /tmp/passed_packages 2>/dev/null | wc -l | tr -d ' ' || echo "0"); \
	FAILED_COUNT=$$(cat /tmp/failed_packages 2>/dev/null | wc -l | tr -d ' ' || echo "0"); \
	rm -f /tmp/total_packages /tmp/passed_packages /tmp/failed_packages; \
	echo "📊 Packages checked: $$TOTAL_COUNT"; \
	echo "✅ Passed: $$PASSED_COUNT"; \
	echo "❌ Failed: $$FAILED_COUNT"; \
	if [ $$FAILED_COUNT -gt 0 ]; then \
		echo ""; \
		echo "💡 For detailed analysis of failed packages, run:"; \
		echo "   make sop-check PACKAGE_NAME=<failed-package-name>"; \
		exit 1; \
	else \
		echo ""; \
		echo "🎉 All extracted packages are properly integrated!"; \
	fi

# Find which package contains a library
sop-find-lib:
	@if [ -z "$(LIBRARY)" ]; then \
		echo "❌ Error: LIBRARY is required"; \
		echo "Usage: make sop-find-lib LIBRARY=libcharset.so"; \
		exit 1; \
	fi
	@echo "🔍 Finding package containing $(LIBRARY)..."
	@if [ ! -f "packages/Contents-aarch64" ]; then \
		echo "❌ packages/Contents-aarch64 not found"; \
		echo "Download from: https://packages.termux.dev/apt/termux-main/dists/stable/Contents-aarch64.gz"; \
		exit 1; \
	fi
	@echo "📋 Results from Contents-aarch64:"
	@grep "$(LIBRARY)" packages/Contents-aarch64 | head -5 || echo "⚠️  Library $(LIBRARY) not found in Contents-aarch64"

# Auto-resolve and add dependencies for a package
sop-add-deps:
	@if [ -z "$(PACKAGE_NAME)" ]; then \
		echo "❌ Error: PACKAGE_NAME is required"; \
		echo "Usage: make sop-add-deps PACKAGE_NAME=git"; \
		exit 1; \
	fi
	@echo "📦 Resolving dependencies for $(PACKAGE_NAME)..."
	@EXTRACT_DIR="packages/$(PACKAGE_NAME)-complete"; \
	if [ ! -d "$$EXTRACT_DIR" ]; then \
		echo "❌ Package $(PACKAGE_NAME) not extracted yet"; \
		echo "Run: make sop-extract PACKAGE_NAME=$(PACKAGE_NAME)"; \
		exit 1; \
	fi; \
	echo "🔍 Checking runtime dependencies..."; \
	find "$$EXTRACT_DIR/data" -name "*.so*" -o -perm +111 -type f 2>/dev/null | while read -r file; do \
		if [ -x "$$file" ] && file "$$file" | grep -q "ELF.*ARM aarch64"; then \
			echo "📄 Analyzing: $$(basename $$file)"; \
			readelf -d "$$file" 2>/dev/null | grep "NEEDED" | sed 's/.*\[\(.*\)\]/  - \1/' || echo "  - No dynamic dependencies"; \
		fi; \
	done

# Download Contents-aarch64 if missing
sop-get-contents:
	@if [ ! -f "packages/Contents-aarch64" ]; then \
		echo "📥 Downloading Contents-aarch64 file..."; \
		mkdir -p packages; \
		# Contents file from termux-main (repository metadata) - compressed format
		wget -O packages/Contents-aarch64.gz "https://packages.termux.dev/apt/termux-main/dists/stable/Contents-aarch64.gz" && gunzip packages/Contents-aarch64.gz || \
		curl -o packages/Contents-aarch64.gz "https://packages.termux.dev/apt/termux-main/dists/stable/Contents-aarch64.gz" && gunzip packages/Contents-aarch64.gz; \
		echo "✅ Downloaded and extracted Contents-aarch64 (45MB)"; \
	else \
		echo "✅ Contents-aarch64 already available"; \
	fi

# Enhanced GitHub release using script
github-release-script:
	@echo "🚀 Creating GitHub release using enhanced script..."
	@./scripts/github-release.sh

github-release-script-dry-run:
	@echo "🧪 Dry run - building APK without creating release..."
	@./scripts/github-release.sh --dry-run

##
## GitHub Release Management Targets
##

github-auth-check:
	@echo "🔐 Checking GitHub CLI authentication..."
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) is not installed"; \
		echo "Install with: brew install gh (macOS) or apt install gh (Ubuntu)"; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "❌ GitHub CLI is not authenticated"; \
		echo "Run: gh auth login"; \
		exit 1; \
	fi
	@echo "✅ GitHub CLI is authenticated"
	@gh auth status

github-tag-version:
	@echo "🏷️ Creating version tag: $(RELEASE_VERSION)"
	@if git tag -l | grep -q "^$(RELEASE_VERSION)$$"; then \
		echo "⚠️  Tag $(RELEASE_VERSION) already exists"; \
		echo "Use: make github-tag-version RELEASE_VERSION=v1.x.x"; \
		exit 1; \
	fi
	@git tag $(RELEASE_VERSION)
	@git push origin $(RELEASE_VERSION)
	@echo "✅ Tagged and pushed $(RELEASE_VERSION)"

github-release-notes:
	@echo "📝 Generating release notes for $(RELEASE_VERSION)..."
	@mkdir -p /tmp
	@printf '# $(RELEASE_TITLE)\n\nBootstrap-free terminal with native Node.js v24.7.0 and AI integration. No package installation required - ready for development immediately.\n\n## ✨ Release Highlights\n- **Instant Setup**: Download, install, develop - no bootstrap required\n- **Native Performance**: Node.js as ARM64 library with W^X compliance\n- **AI Integration**: Built-in Codex CLI for development assistance\n- **Production Ready**: R8 optimized build with comprehensive testing\n\n## 📱 Quick Install\n1. Download APK below → Install on ARM64 Android 14+ device → Launch → Start coding\n\n## 🔐 Release Info\n- **Size**: %s | **SHA256**: %s | **Target**: ARM64 Android 14+\n\n## 📚 Documentation\n**[📖 Full README](https://github.com/WangChengYeh/termux_AI/blob/master/README.md)** - Architecture, workflow, and technical details\n\n**Quick Commands:**\n```bash\nnode --version    # v24.7.0 JavaScript runtime\ncodex --help      # AI assistance\nnpm init -y       # Package management  \nls /usr/bin       # 80+ available tools\n```\n\n## 🚀 What'\''s Included\n**Development:** Node.js v24.7.0, npm v11.5.1, npx | **AI Tools:** Codex CLI/exec | **System:** APT, DPKG, Core Utils (bash, vim, etc.)\n' "$$(ls -lh $(APK) 2>/dev/null | awk '{print $$5}' || echo 'N/A')" "$$(shasum -a 256 $(APK) 2>/dev/null | cut -d' ' -f1 || echo 'N/A')" > /tmp/release-notes.md
	@echo "✅ Release notes generated: /tmp/release-notes.md"

github-release: github-auth-check
	@if [ ! -f "$(APK)" ]; then \
		echo "❌ Release APK not found: $(APK)"; \
		echo "Run: BUILD_TYPE=release make build"; \
		exit 1; \
	fi
	@echo "🚀 Creating GitHub release: $(RELEASE_VERSION)"
	@echo "📦 APK: $(APK)"
	@echo "📝 Title: $(RELEASE_TITLE)"
	@# Create version tag if it doesn't exist
	@if ! git tag -l | grep -q "^$(RELEASE_VERSION)$$"; then \
		echo "🏷️ Creating tag $(RELEASE_VERSION)..."; \
		git tag $(RELEASE_VERSION); \
		git push origin $(RELEASE_VERSION); \
	fi
	@# Generate release notes
	@$(MAKE) github-release-notes
	@# Create GitHub release
	@APK_NAME="$$(basename $(APK) .apk)-$(RELEASE_VERSION).apk"; \
	echo "📤 Uploading APK as: $$APK_NAME"; \
	gh release create $(RELEASE_VERSION) \
		"$(APK)#$$APK_NAME" \
		--title "$(RELEASE_TITLE)" \
		--notes-file /tmp/release-notes.md \
		--target master \
		$(if $(filter true,$(RELEASE_DRAFT)),--draft,) \
		$(if $(filter true,$(RELEASE_PRERELEASE)),--prerelease,)
	@echo "✅ GitHub release created successfully!"
	@echo "🔗 View at: https://github.com/$$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/releases/tag/$(RELEASE_VERSION)"
	@# Clean up temporary files
	@rm -f /tmp/release-notes.md

