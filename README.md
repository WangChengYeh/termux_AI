# Termux AI: Bootstrap-Free Terminal with Native Codex Integration

A modern fork of `termux/termux-app` that eliminates traditional package bootstrapping in favor of direct native executable integration. This implementation places Codex AI tools in Android's read-only `/data/app` directory for W^X (Write XOR Execute) compliance and enhanced security.

**Key Innovation**: No bootstrap installation required - native executables are automatically extracted by Android to read-only system locations and accessed via symbolic links.

![Termux AI in action](termux_ai_screenshot.png)
*Termux AI running Codex CLI with interactive AI assistance*

Important: This fork supports only aarch64 (ARM64, `arm64-v8a`). Other ABIs are not supported.

## Implementation Overview
- **Bootstrap-free architecture**: Eliminates traditional Termux package installation
- **Native executable integration**: Uses Android's `extractNativeLibs=true` mechanism  
- **Read-only security**: Executables reside in `/data/app/.../lib/arm64/` (system-managed, non-writable)
- **Direct access**: Symbolic links provide seamless command execution
- **Android 14+ compatibility**: Full support for latest Android security requirements

## Technical Architecture

### Native Library Integration
- **Source**: Native ARM64 binaries from packages.termux.dev Debian packages
- **Extraction**: `.deb` packages extracted using `ar` and `tar` to obtain native binaries
- **Conversion**: Binaries renamed as `.so` files and placed in `app/src/main/jniLibs/arm64-v8a/`
  - AI tools: `libcodex.so`, `libcodex-exec.so` (custom Codex binaries)
  - Package management: `libapt.so` (from apt_2.8.1-2_aarch64.deb), `libdpkg.so`
  - Development runtime: `libnode.so` (from nodejs_24.7.0_aarch64.deb), `libnpm.so`, `libnpx.so`
  - Core utilities: `libcat.so`, `libecho.so`, `libls.so`, `libpwd.so` (from coreutils)
- **APK Integration**: Gradle packages `.so` files into APK with `extractNativeLibs=true`
- **Extraction**: Android automatically extracts to `/data/app/{package}/lib/arm64/` (read-only)
- **Access**: Symbolic links in `/usr/bin` and `/usr/lib` point to native library paths
- **Security**: W^X compliant - executables in read-only system-managed location

### Bootstrap Replacement
Traditional Termux bootstrap process has been completely replaced:
```java
// Before: Complex zip extraction and package installation
// After: Native executable verification and symbolic link creation
private static void installNativeExecutables(Activity activity) throws Exception {
    String nativeLibDir = activity.getApplicationInfo().nativeLibraryDir;
    // Create symbolic links for all native libraries
    createSymbolicLinks(activity, nativeLibDir);
}
```

### Android Compatibility
- **minSdk**: 34 (Android 14+)
- **targetSdk**: 35 (Android 14+)  
- **Architecture**: ARM64 (`arm64-v8a`) only
- **Distribution**: GitHub Releases (APK)

## Quick Start

1. **Install APK**: Download from [Releases](../../releases) and install on ARM64 Android device
2. **Launch app**: Opens directly with Codex available
3. **Use Codex**: 
   ```bash
   source ~/.profile    # Load aliases  
   codex --help         # AI CLI help
   codex-exec --help    # Non-interactive mode
   ```

## Building from Source

### Prerequisites
- Android SDK with API 35
- Java 17+
- ARM64 Android device or emulator
- ADB in PATH
- `wget` or `curl` for package downloads
- `ar` and `tar` for Debian package extraction

## Standard Operating Procedure: Adding Packages to APK

### Overview

This SOP describes the systematic process of integrating Debian packages from packages.termux.dev into the bootstrap-free Termux AI APK. Executables are embedded as native libraries (`.so` files) and accessed via symbolic links created at runtime.

**📋 Quick Start**: Use the automated workflow: `make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0`

**🔧 Manual Process**: Follow the 7-step process below for detailed control or learning purposes.

### Step 1: List Available Packages

Browse available packages at the Termux packages repository:
```bash
# Browse package categories at https://packages.termux.dev/apt/termux-main/pool/main/

# Search for specific packages starting with letter 'n' (example: nodejs)
curl -s "https://packages.termux.dev/apt/termux-main/pool/main/n/" | grep -o 'href="[^"]*\.deb"' | sed 's/href="//g' | sed 's/"//g'

# For packages starting with 'lib' prefix, check:
curl -s "https://packages.termux.dev/apt/termux-main/pool/main/liba/" | grep -o 'href="[^"]*\.deb"'
```

Package categories are organized alphabetically by first letter:
- `/main/a/` - packages starting with 'a' (apt, android-tools)
- `/main/n/` - packages starting with 'n' (nodejs, nano)
- `/main/liba/` - lib packages starting with 'liba' (libandroid-support)

### Step 2: Download Package

Download the desired aarch64 package to the packages directory:
```bash
# Create packages directory if it doesn't exist
mkdir -p packages
cd packages

# Download package (example: Node.js)
wget -O nodejs_24.7.0_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main/pool/main/n/nodejs/nodejs_24.7.0_aarch64.deb"

# Download dependency package (example: libandroid-support)
wget -O libandroid-support_29-1_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main/pool/main/liba/libandroid-support/libandroid-support_29-1_aarch64.deb"
```

### Step 3: Extract Package Contents

Extract the `.deb` package using dpkg-deb to analyze its structure:
```bash
# Extract package contents
mkdir -p nodejs-extract
dpkg-deb -x nodejs_24.7.0_aarch64.deb nodejs-extract/

# Extract dependency package
mkdir -p libandroid-support-extract  
dpkg-deb -x libandroid-support_29-1_aarch64.deb libandroid-support-extract/
```

### Step 4: Analyze Package Structure

Examine the extracted contents to identify executables and libraries:
```bash
# Find all executables in /usr/bin
find nodejs-extract -type f -path "*/usr/bin/*"
# Output: nodejs-extract/data/data/com.termux/files/usr/bin/node
#         nodejs-extract/data/data/com.termux/files/usr/bin/npm
#         nodejs-extract/data/data/com.termux/files/usr/bin/npx

# Find all libraries in /usr/lib
find nodejs-extract -type f -path "*/usr/lib/*" -name "*.so*"

# Check file types to determine native executables vs scripts
file nodejs-extract/data/data/com.termux/files/usr/bin/node
# Expected outputs:
# - Native: ARM aarch64 ELF 64-bit LSB pie executable
# - Script: ASCII text executable, or symbolic link

# For native executables, check library dependencies
readelf -d nodejs-extract/data/data/com.termux/files/usr/bin/node | grep NEEDED

# Identify file types for proper handling
for file in nodejs-extract/data/data/com.termux/files/usr/bin/*; do
  echo "$(basename "$file"): $(file "$file" | cut -d: -f2)"
done
```

### Step 5: Copy Files to Android APK Structure

Copy files based on their type - native executables use Android JNI naming, scripts are copied directly:

#### 5.1 Copy Native Executables to jniLibs
```bash
# Create jniLibs directory
mkdir -p app/src/main/jniLibs/arm64-v8a

# For NATIVE EXECUTABLES (ARM64 ELF binaries):
# Copy with lib prefix and .so extension (Android naming convention)
cp nodejs-extract/data/data/com.termux/files/usr/bin/node app/src/main/jniLibs/arm64-v8a/libnode.so
chmod +x app/src/main/jniLibs/arm64-v8a/libnode.so
```

#### 5.2 Copy Scripts and Non-Native Files to Assets
```bash
# Create assets directory structure
mkdir -p app/src/main/assets/termux/usr/bin

# For SCRIPTS, SYMBOLIC LINKS, and NON-NATIVE FILES:
# Copy directly maintaining directory structure (no renaming needed)
cp nodejs-extract/data/data/com.termux/files/usr/bin/npm app/src/main/assets/termux/usr/bin/npm
cp nodejs-extract/data/data/com.termux/files/usr/bin/npx app/src/main/assets/termux/usr/bin/npx
chmod +x app/src/main/assets/termux/usr/bin/npm
chmod +x app/src/main/assets/termux/usr/bin/npx

# Copy entire supporting directories for script dependencies
cp -r nodejs-extract/data/data/com.termux/files/usr/lib/node_modules \
      app/src/main/assets/termux/usr/lib/
```

#### 5.3 Copy Libraries to jniLibs
```bash
# Copy shared libraries directly (keep original names)
cp libandroid-support-extract/data/data/com.termux/files/usr/lib/libandroid-support.so \
   app/src/main/jniLibs/arm64-v8a/

# Set executable permissions
chmod +x app/src/main/jniLibs/arm64-v8a/libandroid-support.so
```

### Step 6: Update TermuxInstaller.java

Edit `app/src/main/java/com/termux/app/TermuxInstaller.java` to handle both native executables and script files:

#### 6.1 For Native Executables (in jniLibs)
Add symbolic link mappings for native executables:
```java
String[][] executables = {
    // Existing entries...
    {"libcodex.so", "codex"},
    {"libcodex-exec.so", "codex-exec"},
    {"libapt.so", "apt"},
    
    // Add new native executables only
    {"libnode.so", "node"},
    {"libenv.so", "env"},
    {"libprintenv.so", "printenv"},
};
```

#### 6.2 For Scripts and Non-Native Files (in assets)
Add asset extraction logic for script files:
```java
// Extract assets to runtime directory during installation
private static void extractAssets(Context context) throws Exception {
    AssetManager assets = context.getAssets();
    String termuxDir = "/data/data/com.termux/files";
    
    // Extract usr/bin scripts
    extractAssetDirectory(assets, "termux/usr/bin", termuxDir + "/usr/bin");
    
    // Extract usr/lib supporting files
    extractAssetDirectory(assets, "termux/usr/lib", termuxDir + "/usr/lib");
}
```

**Result**: 
- **Native executables**: `/data/data/com.termux/files/usr/bin/node` → symlink to `/data/app/{package}/lib/arm64/libnode.so`
- **Script files**: `/data/data/com.termux/files/usr/bin/npm` → direct file copied from assets with dependencies intact

### Step 7: Build and Test

Build and install the updated APK:
```bash
# Clean, build and install using Makefile
make clean && make && make install

# Test functionality
adb shell am start -n com.termux/.app.TermuxActivity

# Test commands in Termux terminal
# node --version
# npm --version
```

## SOP Makefile Automation

### Overview

The SOP process has been fully automated through Makefile targets, reducing the entire 7-step workflow to a single command while maintaining individual step control for advanced users.

### Complete Automated Workflow

Execute the entire SOP with one command:
```bash
# Complete package integration workflow
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0

# Library-only packages
make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1

# Other examples
make sop-add-package PACKAGE_NAME=nano VERSION=8.2
```

### Individual SOP Step Control

For manual control or debugging, execute individual SOP steps:

#### Step 1: List Available Packages
```bash
# List packages starting with 'n' (nodejs, nano, etc.)
make sop-list LETTER=n

# List library packages starting with 'liba'
make sop-list LETTER=liba

# List packages starting with 'd' (dpkg, etc.)
make sop-list LETTER=d
```

#### Step 2: Download Package
```bash
make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0
```

#### Step 3: Extract Package
```bash
make sop-extract PACKAGE_NAME=nodejs
```

#### Step 4: Analyze Structure
```bash
make sop-analyze PACKAGE_NAME=nodejs
# Shows: executables, libraries, file types, ARM64 verification
```

#### Step 5: Copy Files to Android Structure
```bash
make sop-copy PACKAGE_NAME=nodejs
# Automatically applies Android naming conventions and permissions
```

#### Step 6: Update TermuxInstaller.java
```bash
make sop-update PACKAGE_NAME=nodejs
# Generates code snippets for manual integration (if executables found)
```

#### Step 7: Build and Test
```bash
make sop-build
# Executes: make clean build install
```

### Advanced Features

#### Smart URL Resolution
- **Regular packages**: Automatically resolves `n/nodejs/` paths
- **Library packages**: Handles `liba/libandroid-support/` paths
- **Error handling**: Validates parameters and provides usage examples

#### File Analysis and Integration
- **ARM64 verification**: Confirms ELF 64-bit ARM aarch64 binaries
- **Android naming**: Executables → `lib*.so`, Libraries → original names
- **Permissions**: Automatically sets executable permissions
- **Structure analysis**: Shows executables vs libraries for integration planning

#### TermuxInstaller.java Integration
- **Executable detection**: Identifies files requiring symbolic link entries
- **Code generation**: Provides exact Java array entries for copy-paste
- **Library handling**: Correctly identifies library-only packages (no update needed)

#### Example Output
```bash
$ make sop-analyze PACKAGE_NAME=nodejs
🔍 SOP Step 4: Analyze nodejs package structure

Executables in /usr/bin:
packages/nodejs-extract/data/data/com.termux/files/usr/bin/node
packages/nodejs-extract/data/data/com.termux/files/usr/bin/npm
packages/nodejs-extract/data/data/com.termux/files/usr/bin/npx

Libraries in /usr/lib:
(none found)

File types:
  node:  ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, stripped
  npm:  symbolic link to ../lib/node_modules/npm/bin/npm-cli.js
  npx:  symbolic link to ../lib/node_modules/npm/bin/npx-cli.js
```

### Help and Usage
```bash
# Show general help including SOP section
make help

# Show detailed SOP usage and examples
make sop-help
```

## Package Integration Examples

### Example 1: Complete Node.js Ecosystem (Mixed Native + Scripts)

```bash
# 1. Download Node.js package
wget -O packages/nodejs_24.7.0_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main/pool/main/n/nodejs/nodejs_24.7.0_aarch64.deb"

# 2. Extract and analyze file types
mkdir -p packages/nodejs-extract
dpkg-deb -x packages/nodejs_24.7.0_aarch64.deb packages/nodejs-extract/

# Check file types to determine handling
file packages/nodejs-extract/data/data/com.termux/files/usr/bin/node
# Output: ARM aarch64 ELF 64-bit LSB pie executable (NATIVE - use jniLibs)

file packages/nodejs-extract/data/data/com.termux/files/usr/bin/npm
# Output: symbolic link to ../lib/node_modules/npm/bin/npm-cli.js (SCRIPT - use assets)

# 3. Handle NATIVE executable (node)
mkdir -p app/src/main/jniLibs/arm64-v8a/
cp packages/nodejs-extract/data/data/com.termux/files/usr/bin/node \
   app/src/main/jniLibs/arm64-v8a/libnode.so
chmod +x app/src/main/jniLibs/arm64-v8a/libnode.so

# 4. Handle SCRIPT files (npm, npx) and dependencies
mkdir -p app/src/main/assets/termux/usr/bin
mkdir -p app/src/main/assets/termux/usr/lib

# Copy scripts directly (no renaming)
cp packages/nodejs-extract/data/data/com.termux/files/usr/bin/npm \
   app/src/main/assets/termux/usr/bin/npm
cp packages/nodejs-extract/data/data/com.termux/files/usr/bin/npx \
   app/src/main/assets/termux/usr/bin/npx

# Copy complete dependency tree for scripts
cp -r packages/nodejs-extract/data/data/com.termux/files/usr/lib/node_modules \
      app/src/main/assets/termux/usr/lib/

# 5. Update TermuxInstaller.java (only for native executables)
{"libnode.so", "node"},  # Only native node binary needs symlink
# npm and npx handled automatically by asset extraction
```

### Example 2: DPKG Package Management Suite

```bash
# 1. Download DPKG package
wget -O packages/dpkg_1.22.6-4_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main/pool/main/d/dpkg/dpkg_1.22.6-4_aarch64.deb"

# 2. Extract and find all DPKG utilities
dpkg-deb -x packages/dpkg_1.22.6-4_aarch64.deb packages/dpkg-extract/
find packages/dpkg-extract -path "*/usr/bin/*" -type f
# Output shows: dpkg, dpkg-deb, dpkg-query, dpkg-split, etc.

# 3. Copy all utilities with batch script
for file in packages/dpkg-extract/data/data/com.termux/files/usr/bin/*; do
  filename=$(basename "$file")
  cp "$file" "app/src/main/jniLibs/arm64-v8a/lib${filename}.so"
  chmod +x "app/src/main/jniLibs/arm64-v8a/lib${filename}.so"
done

# 4. Update TermuxInstaller.java with all DPKG tools
{"libdpkg.so", "dpkg"},
{"libdpkg-deb.so", "dpkg-deb"},
{"libdpkg-query.so", "dpkg-query"},
{"libdpkg-split.so", "dpkg-split"},
// ... additional DPKG utilities
```

### Example 3: Dependency Resolution (libandroid-support)

```bash
# 1. Download dependency library
wget -O packages/libandroid-support_29-1_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main/pool/main/liba/libandroid-support/libandroid-support_29-1_aarch64.deb"

# 2. Extract shared library
dpkg-deb -x packages/libandroid-support_29-1_aarch64.deb packages/libandroid-support-extract/
find packages/libandroid-support-extract -name "*.so*"
# Output: libandroid-support-extract/data/data/com.termux/files/usr/lib/libandroid-support.so

# 3. Copy library (keep original name)
cp packages/libandroid-support-extract/data/data/com.termux/files/usr/lib/libandroid-support.so \
   app/src/main/jniLibs/arm64-v8a/
chmod +x app/src/main/jniLibs/arm64-v8a/libandroid-support.so

# 4. No TermuxInstaller.java update needed for libraries (only for executables)
```

## Android Integration Rules

### Native Executable Files (ARM64 ELF binaries)
- **Source**: `/data/data/com.termux/files/usr/bin/executable` (file type: ARM aarch64 ELF)
- **Target**: `app/src/main/jniLibs/arm64-v8a/libexecutable.so` (Android naming convention)
- **Runtime**: `/data/data/com.termux/files/usr/bin/executable` → symlink to `/data/app/{package}/lib/arm64/libexecutable.so`
- **TermuxInstaller**: Requires entry in executables array

### Script Files and Non-Native Executables
- **Source**: `/data/data/com.termux/files/usr/bin/script` (file type: ASCII text, symbolic link, etc.)
- **Target**: `app/src/main/assets/termux/usr/bin/script` (direct copy, no renaming)
- **Runtime**: `/data/data/com.termux/files/usr/bin/script` → direct file extracted from assets
- **Dependencies**: Supporting directories (like node_modules) also copied to assets
- **TermuxInstaller**: No entry needed, handled by asset extraction

### Shared Libraries  
- **Source**: `/data/data/com.termux/files/usr/lib/library.so`
- **Target**: `app/src/main/jniLibs/arm64-v8a/library.so` (keep original name)
- **Access**: Direct library loading, no symlink needed
- **TermuxInstaller**: No entry needed

### Permissions
All files must have executable permissions:
```bash
# For jniLibs
chmod +x app/src/main/jniLibs/arm64-v8a/*.so

# For assets (after extraction at runtime)
chmod +x /data/data/com.termux/files/usr/bin/*
```

## Directory Structure

```
Project Structure:
├── packages/                          # Downloaded .deb packages
│   ├── nodejs_24.7.0_aarch64.deb
│   ├── nodejs-extract/                # Extracted package contents
│   └── libandroid-support-extract/
├── app/src/main/jniLibs/arm64-v8a/   # Native executables & shared libraries
│   ├── libnode.so                     # Node.js runtime (native executable)
│   ├── libandroid-support.so          # Support library (shared lib)
│   └── ...
├── app/src/main/assets/termux/        # Scripts and supporting files
│   ├── usr/bin/
│   │   ├── npm                        # npm script (non-native)
│   │   ├── npx                        # npx script (non-native)
│   │   └── ...
│   └── usr/lib/
│       └── node_modules/              # Complete Node.js ecosystem
└── app/src/main/java/com/termux/app/
    └── TermuxInstaller.java           # Symlink creation & asset extraction

Runtime Structure:
/data/data/com.termux/files/usr/
├── bin/                               # Mixed: symlinks + direct files
│   ├── node -> /data/app/{package}/lib/arm64/libnode.so        # Native (symlink)
│   ├── npm                            # Script (direct file from assets)
│   ├── npx                            # Script (direct file from assets)
│   └── ...
└── lib/                              # Libraries + dependencies from assets
    ├── libandroid-support.so          # Shared library (copied from jniLibs)
    └── node_modules/                  # Complete dependency tree from assets

Android System Structure:
/data/app/{package}/lib/arm64/         # Read-only native libraries (extracted by Android)
├── libnode.so                         # Native Node.js executable
├── libandroid-support.so              # Support libraries
└── ...
```

### Native Package Integration Flow

#### 1. Download Termux Packages
```bash
# Node.js runtime (24.7.0)
wget https://packages.termux.dev/apt/termux-main/pool/main/n/nodejs/nodejs_24.7.0_aarch64.deb

# APT package manager (2.8.1-2)  
wget https://packages.termux.dev/apt/termux-main/pool/main/a/apt/apt_2.8.1-2_aarch64.deb

# Additional packages as needed
wget https://packages.termux.dev/apt/termux-main/pool/main/d/dpkg/dpkg_1.22.6-1_aarch64.deb
```

#### 2. Extract Native Binaries
```bash
# Create extraction directory
mkdir -p native-binaries

# Extract .deb packages
for pkg in *.deb; do
    ar x "$pkg" data.tar.xz
    tar -xJf data.tar.xz -C native-binaries/
    rm data.tar.xz
done

# Locate ARM64 binaries
find native-binaries -name "node" -type f
# → native-binaries/data/data/com.termux/files/usr/bin/node

find native-binaries -name "apt" -type f  
# → native-binaries/data/data/com.termux/files/usr/bin/apt
```

#### 3. Convert to Android Native Libraries
```bash
# Copy binaries and rename as .so files for Android integration
mkdir -p app/src/main/jniLibs/arm64-v8a/

# Node.js ecosystem
cp native-binaries/data/data/com.termux/files/usr/bin/node app/src/main/jniLibs/arm64-v8a/libnode.so
cp native-binaries/data/data/com.termux/files/usr/bin/npm app/src/main/jniLibs/arm64-v8a/libnpm.so  
cp native-binaries/data/data/com.termux/files/usr/bin/npx app/src/main/jniLibs/arm64-v8a/libnpx.so

# Package management
cp native-binaries/data/data/com.termux/files/usr/bin/apt app/src/main/jniLibs/arm64-v8a/libapt.so
cp native-binaries/data/data/com.termux/files/usr/bin/dpkg app/src/main/jniLibs/arm64-v8a/libdpkg.so

# Verify executable permissions
chmod +x app/src/main/jniLibs/arm64-v8a/*.so
```

#### 4. Dependency Resolution
```bash
# Check runtime dependencies
readelf -d app/src/main/jniLibs/arm64-v8a/libnode.so | grep NEEDED
# Extract required shared libraries from packages and include as additional .so files

# Common Termux dependencies:
# - libc++_shared.so (from ndk-sysroot)
# - libandroid-support.so (from android-support package)
```

### Build & Install
```bash
make doctor          # Verify environment
make build           # Build debug APK  
make install         # Install via ADB
make run             # Launch app

# SOP Package Integration (see SOP section for details)
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0  # Complete workflow
make sop-help        # Show SOP automation usage
```

## Implementation Details

### Key Files Modified
- **`TermuxInstaller.java`**: Replaced bootstrap with native executable verification
- **`TermuxShellEnvironment.java`**: Simplified PATH to `/system/bin` only
- **`AndroidManifest.xml`**: Added Android 14+ foreground service permissions
- **`TermuxActivity.java`**: Fixed broadcast receiver export flags

### Native Executable Flow
1. **Package Download**: Download ARM64 `.deb` packages from packages.termux.dev
2. **Binary Extraction**: Extract native binaries from Debian packages using `ar` and `tar`
3. **Library Conversion**: Copy binaries to `app/src/main/jniLibs/arm64-v8a/` as `.so` files
4. **Dependency Resolution**: Include required shared libraries for runtime dependencies
5. **Build Integration**: Gradle packages `.so` files into APK with `extractNativeLibs=true`
6. **Install time**: Android extracts libraries to `/data/app/{hash}/lib/arm64/` (read-only)
7. **First run**: App creates symbolic links in `/usr/bin` and `/usr/lib` pointing to extracted libraries
8. **Runtime**: Users execute commands via symbolic links that resolve to native library paths

### Android 14+ Compatibility  
Fixed multiple compatibility issues for modern Android:
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<service android:name=".app.TermuxService" 
         android:foregroundServiceType="specialUse">
    <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" 
              android:value="terminal" />
</service>
```

```java
// TermuxActivity.java  
registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
```

## Available Commands

After app launch, the following commands are available via symbolic links:

### AI Tools
- **`codex`**: AI CLI for interactive AI assistance
- **`codex-exec`**: Non-interactive AI command execution  

### Native Package Tools (APT Integration)
- **`apt`**: Package manager for installing additional ARM64 packages
- **`pkg`**: Simplified package management wrapper
- **`dpkg`**: Debian package management utilities

### Development Runtime
- **`node`**: Node.js runtime for JavaScript development
- **`npm`**: Node Package Manager for installing JavaScript packages
- **`npx`**: Node Package Execute for running packages without installing

### Core Utilities
- **`cat`**, **`echo`**, **`ls`**, **`pwd`**: Essential shell commands via native libraries

Example usage:
```bash
# Commands are available directly in PATH
# AI assistance
codex --help
codex "explain this command: ls -la"
codex-exec "write a shell script to backup files"

# Package management
apt update && apt upgrade
pkg install python
dpkg -l | grep python

# Node.js development
node --version
npm --version
npx --version
npm init -y
npm install express
npx create-react-app myapp

# Core utilities  
ls -la
cat file.txt
echo "Hello World"
```

## Symbolic Link System

The app automatically creates a comprehensive symbolic link system:

### Executable Symlinks (`/usr/bin`)
```bash
# AI Tools
/usr/bin/codex -> /data/app/{hash}/lib/arm64/libcodex.so
/usr/bin/codex-exec -> /data/app/{hash}/lib/arm64/libcodex-exec.so

# Package Management
/usr/bin/apt -> /data/app/{hash}/lib/arm64/libapt.so
/usr/bin/node -> /data/app/{hash}/lib/arm64/libnode.so
```

### Library Symlinks (`/usr/lib`)
```bash
# Core libraries for dependency resolution
/usr/lib/libandroid-glob.so -> /data/app/{hash}/lib/arm64/libandroid-glob.so
/usr/lib/libapt-private.so -> /data/app/{hash}/lib/arm64/libapt-private.so
/usr/lib/libapt-pkg.so -> /data/app/{hash}/lib/arm64/libapt-pkg.so

# Zlib with versioned symlinks for Node.js compatibility
/usr/lib/libz.so -> /data/app/{hash}/lib/arm64/libzlib.so
/usr/lib/libz.so.1 -> /usr/lib/libz.so          # Versioned symlink
/usr/lib/libz.so.1.3.1 -> /usr/lib/libz.so      # Full version symlink
```

### Environment Configuration
```bash
# Termux shell profile
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr
export PATH=/data/data/com.termux/files/usr/bin:$PATH
export LD_LIBRARY_PATH=/data/app/{hash}/lib/arm64:/data/data/com.termux/files/usr/lib:$LD_LIBRARY_PATH
```

## Security & Compliance

### W^X (Write XOR Execute) Policy
- **Problem**: Android 10+ prevents execution of files in writable app directories
- **Solution**: Native libraries in read-only `/data/app` system location
- **Benefit**: Enhanced security - executables cannot be modified after installation

### SELinux Compatibility
- Uses Android's native library extraction mechanism
- Inherits proper SELinux contexts automatically
- No custom security policy modifications required

### Permissions
```xml
<!-- Required for Android 14+ foreground services -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

<!-- Standard Termux permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

## Differences from Standard Termux

### Hybrid Package Management
- **Traditional Termux**: Uses `pkg install` with full APT bootstrap installation
- **Termux AI**: Native library integration + selective APT functionality
  - Core tools (codex, cat, ls, etc.) as native libraries
  - APT/pkg available for additional packages when needed
  - Best of both worlds: instant availability + extensibility

### Optimized Environment  
- **PATH**: `/usr/bin:/system/bin` with symbolic links to native executables
- **LD_LIBRARY_PATH**: Native lib directory + `/usr/lib` for dependency resolution
- **Core Executables**: Direct access via symbolic links to read-only locations
- **Versioned Libraries**: Symlinks handle version compatibility (e.g., libz.so.1)
- **Additional Packages**: Available through integrated APT when needed

### Enhanced Security
- **Execution**: Read-only native libraries prevent runtime modification
- **Permissions**: Minimal permission set for AI functionality
- **Isolation**: Native executables run with app permissions and SELinux context

## Development Workflow

### Complete Build Process
```bash
# 1. Environment setup
make doctor           # Check tools (adb, gradlew)
make devices          # List connected devices  
make verify-abi       # Ensure device is ARM64

# 2. Package integration (automated SOP workflow)
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0     # Complete integration
make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1  # Dependencies

# Alternative: Manual package integration (for learning/debugging)
# ./scripts/download-packages.sh   # Download .deb packages from packages.termux.dev
# ./scripts/extract-natives.sh     # Extract binaries and convert to .so files
# ./scripts/resolve-deps.sh         # Include runtime dependencies

# 3. Build and test
make build            # Build debug APK with native libraries
make lint test        # Code quality checks
make install          # Install on device
make run             # Launch app
make logs            # Monitor logs

# 4. Maintenance  
make clean           # Clean build outputs
make uninstall       # Remove from device
```

### Automated Native Integration Scripts

#### Package Download Script (`scripts/download-packages.sh`)
```bash
#!/bin/bash
set -e

PACKAGES_DIR="packages"
mkdir -p "$PACKAGES_DIR"
cd "$PACKAGES_DIR"

# Core packages with versions
wget -N https://packages.termux.dev/apt/termux-main/pool/main/n/nodejs/nodejs_24.7.0_aarch64.deb
wget -N https://packages.termux.dev/apt/termux-main/pool/main/a/apt/apt_2.8.1-2_aarch64.deb
wget -N https://packages.termux.dev/apt/termux-main/pool/main/d/dpkg/dpkg_1.22.6-1_aarch64.deb

echo "Package download complete"
```

#### Binary Extraction Script (`scripts/extract-natives.sh`)
```bash
#!/bin/bash
set -e

PACKAGES_DIR="packages"
NATIVES_DIR="native-binaries"
JNI_DIR="app/src/main/jniLibs/arm64-v8a"

# Clean and setup directories
rm -rf "$NATIVES_DIR" "$JNI_DIR"
mkdir -p "$NATIVES_DIR" "$JNI_DIR"

# Extract all .deb packages
for pkg in "$PACKAGES_DIR"/*.deb; do
    echo "Extracting $(basename "$pkg")..."
    ar x "$pkg" data.tar.xz
    tar -xJf data.tar.xz -C "$NATIVES_DIR/"
    rm data.tar.xz
done

# Convert binaries to .so files
TERMUX_PREFIX="$NATIVES_DIR/data/data/com.termux/files/usr/bin"

# Node.js ecosystem
cp "$TERMUX_PREFIX/node" "$JNI_DIR/libnode.so"
cp "$TERMUX_PREFIX/npm" "$JNI_DIR/libnpm.so"
cp "$TERMUX_PREFIX/npx" "$JNI_DIR/libnpx.so"

# Package management
cp "$TERMUX_PREFIX/apt" "$JNI_DIR/libapt.so"
cp "$TERMUX_PREFIX/dpkg" "$JNI_DIR/libdpkg.so"

# Set executable permissions
chmod +x "$JNI_DIR"/*.so

echo "Native library conversion complete"
```

### Release Process
```bash
# Full release build with native integration
./scripts/download-packages.sh   # Ensure latest packages
./scripts/extract-natives.sh     # Refresh native libraries
BUILD_TYPE=release make build     # Build release APK
make lint test                   # Final validation
```

## Testing & Verification

### Manual Testing (ARM64 only)
```bash
# Install and launch
make install run

# Connect to app and test functionality
adb shell run-as com.termux
cd /data/data/com.termux/files/home
codex --help         # Should show AI CLI help
codex-exec --help    # Should show non-interactive help
node --version       # Should show Node.js version
npm --version        # Should show NPM version
npx --version        # Should show NPX version
```

### Build Verification
```bash
make lint test       # Code quality and unit tests
make verify-abi      # Ensure ARM64 device
make logs           # Monitor app behavior
```

## Known Limitations
- **ARM64 only**: Other architectures not supported  
- **Android 14+ required**: Minimum API level 34
- **Selective packaging**: Only essential packages included as native libraries
- **Bootstrap-free**: Traditional Termux bootstrap replaced with direct integration

## Project Status
✅ **Completed**:
- Bootstrap removal and native executable integration
- Android 14+ compatibility (foreground services, receivers)  
- Read-only `/data/app` placement with W^X compliance
- Symbolic link system for seamless command execution
- Makefile build system with ARM64 verification
- Hybrid package management (native libraries + selective APT)

🎯 **Current Implementation**:
- Native Codex CLI available immediately after app launch
- Integrated APT/pkg package management for extensibility
- Node.js runtime and NPM for JavaScript development
- Core utilities (cat, ls, echo, pwd) as native libraries
- No internet required for core AI functionality  
- Secure read-only executable placement
- Compatible with latest Android security policies

### Package Integration Details
- **Source packages**: ARM64 Debian packages from packages.termux.dev repository
- **Core tools**: Embedded as native libraries for instant access (Node.js 24.7.0, APT 2.8.1-2)
- **APT integration**: Package manager available for additional software installation
- **Node.js runtime**: Full JavaScript development environment included with npm/npx
- **Automated workflow**: Scripts handle download, extraction, and .so conversion
- **Hybrid approach**: Performance + flexibility without traditional bootstrap overhead

## License
Follows upstream Termux licensing. See individual component licenses for native binaries.