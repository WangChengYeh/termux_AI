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

.PHONY: help build release lint test clean install uninstall run logs devices abi verify-abi doctor grant-permissions check-jnilibs check-packages check-duplicates sop-help sop-list sop-download sop-extract sop-analyze sop-copy sop-update sop-build sop-test sop-user-test sop-add-package

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
	@echo "  sop-user-test   - Automated command testing via ADB"
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
	@echo "  make sop-extract PACKAGE_NAME=nodejs"
	@echo "  make sop-analyze PACKAGE_NAME=nodejs"
	@echo "  make sop-copy PACKAGE_NAME=nodejs"
	@echo "  make sop-update PACKAGE_NAME=nodejs      # Updates TermuxInstaller.java if needed"
	@echo "  make sop-build                           # Build and test integration"
	@echo ""
	@echo "Package Analysis:"
	@echo "  make extract-package PACKAGE_NAME=libgmp # Extract complete package (data + control)"
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
	@adb shell am start -n "$(APP_ID)/.app.TermuxActivity" >/dev/null 2>&1 || true
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
	@echo "🧪 SOP User Testing: Simulating user interactions via ADB input"
	@echo ""
	@echo "📱 Launching Termux AI..."
	@adb shell am start -n "$(APP_ID)/.app.TermuxActivity" >/dev/null 2>&1 || true
	@sleep 3
	@echo "🖥️  App launched, waiting for terminal to be ready..."
	@sleep 2
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "⌨️  Simulating User Input Tests:"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🔍 Test 1: Basic command execution"
	@echo -n "   Typing 'pwd' + Enter: "
	@adb shell input text "pwd" && adb shell input keyevent 66 && sleep 1 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 2: Environment setup" 
	@echo -n "   Typing 'source .profile' + Enter: "
	@adb shell input text "source\\ .profile" && adb shell input keyevent 66 && sleep 1 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 3: Node.js version check"
	@echo -n "   Typing 'node --version' + Enter: "
	@adb shell input text "node\\ --version" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 4: NPM version check"
	@echo -n "   Typing 'npm --version' + Enter: "
	@adb shell input text "npm\\ --version" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 5: List available commands"
	@echo -n "   Typing 'ls /usr/bin' + Enter: "
	@adb shell input text "ls\\ /usr/bin" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 6: Check PATH environment"
	@echo -n "   Typing 'echo \$$PATH' + Enter: "
	@adb shell input text "echo\\ \$$PATH" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 7: Test AI tools availability"
	@echo -n "   Typing 'command -v codex' + Enter: "
	@adb shell input text "command\\ -v\\ codex" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 8: Test symbolic links"
	@echo -n "   Typing 'file /usr/bin/node' + Enter: "
	@adb shell input text "file\\ /usr/bin/node" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 9: Check library dependencies"
	@echo -n "   Typing 'ldd /usr/bin/node | head -3' + Enter: "
	@adb shell input text "ldd\\ /usr/bin/node\\ \\|\\ head\\ -3" && adb shell input keyevent 66 && sleep 3 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 10: APT package manager"
	@echo -n "   Typing 'apt --version' + Enter: "
	@adb shell input text "apt\\ --version" && adb shell input keyevent 66 && sleep 2 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 2
	@echo ""
	@echo "🔍 Test 11: Clear screen for visibility"
	@echo -n "   Typing 'clear' + Enter: "
	@adb shell input text "clear" && adb shell input keyevent 66 && sleep 1 && echo "✅ Sent" || echo "❌ FAILED"
	@sleep 1
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════"
	@echo "🏁 User simulation completed!"
	@echo ""
	@echo "📋 Commands tested via UI input:"
	@echo "   ✓ pwd - Working directory check"
	@echo "   ✓ source .profile - Environment setup"
	@echo "   ✓ node --version - Node.js runtime"
	@echo "   ✓ npm --version - Package manager"
	@echo "   ✓ ls /usr/bin - Available commands"
	@echo "   ✓ echo \$$PATH - Environment variables"
	@echo "   ✓ command -v codex - AI tools availability"
	@echo "   ✓ file /usr/bin/node - Symbolic link verification"
	@echo "   ✓ ldd /usr/bin/node - Library dependencies"
	@echo "   ✓ apt --version - Package management"
	@echo ""
	@echo "📱 Check the Termux app screen to see command results"
	@echo "   Use 'adb shell screencap' to capture screen if needed"

