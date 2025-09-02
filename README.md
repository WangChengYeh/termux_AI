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
  - Development runtime: `libnode.so` (from nodejs_24.7.0_aarch64.deb), npm/npx scripts
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

**🚀 Recommended Approach**: Use the automated Makefile workflow for reliable, consistent integration.

**📋 Complete Integration (Recommended)**:
```bash
# Single command for complete package integration
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0
```

**🔍 Package Analysis**:
```bash
# Analyze package contents before integration
make extract-package PACKAGE_NAME=nodejs
```

### Makefile SOP Commands

The SOP has been fully automated through Makefile targets. Use these commands instead of manual steps:

#### Step 1: List Available Packages
```bash
# List packages starting with specific letters
make sop-list LETTER=n              # nodejs, nano, ncurses
make sop-list LETTER=liba           # libandroid-support, libapt-pkg  
make sop-list LETTER=c              # coreutils, curl
make sop-list LETTER=g              # git, gcc, gmp
```

#### Step 2: Download Package
```bash
# Download specific package versions
make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0
make sop-download PACKAGE_NAME=libandroid-support VERSION=29-1
make sop-download PACKAGE_NAME=coreutils VERSION=9.7-3
```

#### Step 3: Extract Package Contents  
```bash
# Extract for standard integration
make sop-extract PACKAGE_NAME=nodejs

# Extract complete package (data + control files) for analysis
make extract-package PACKAGE_NAME=nodejs
```

#### Step 4: Analyze Package Structure
```bash
# Analyze package contents and identify file types
make sop-analyze PACKAGE_NAME=nodejs

# Shows:
# - Native executables (need TermuxInstaller.java entries)
# - Script files (handled automatically by asset extraction) 
# - Libraries and dependencies
# - Integration recommendations
```

#### Step 5: Copy Files to Android APK Structure
```bash
# Automatically copy files to proper Android structure
make sop-copy PACKAGE_NAME=nodejs

# Handles:
# - Native executables → jniLibs/arm64-v8a/ with lib*.so naming
# - Script files → assets/termux/ maintaining directory structure  
# - Libraries → jniLibs/arm64-v8a/ with original names
# - Sets proper permissions automatically
```

#### Step 6: Update TermuxInstaller.java
```bash
# Generate TermuxInstaller.java entries for native executables
make sop-update PACKAGE_NAME=nodejs

# Output shows code to add to TermuxInstaller.java:
# {"libnode.so", "node"},  # Add to executables array
# 
# Script files (npm, npx) are handled automatically by asset extraction
```

#### Step 7: Build and Test
```bash
# Build, install and test integration  
make sop-build

# Equivalent to:
# make clean build install
# Launches Termux app for testing
```

### Complete Automated Workflow

**✅ Recommended**: Use the complete automation for reliable integration:

```bash  
# Complete package integration (all 7 steps)
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0
make sop-add-package PACKAGE_NAME=coreutils VERSION=9.7-3
make sop-add-package PACKAGE_NAME=libgmp VERSION=6.3.0-2
make sop-add-package PACKAGE_NAME=pcre2 VERSION=10.46
```

**🔍 Analysis & Troubleshooting**:

```bash
# Get help with all SOP commands
make sop-help

# Analyze package before integration
make extract-package PACKAGE_NAME=nodejs

# Check for duplicate libraries  
make check-duplicates
```

**Real-world Examples**:
```bash
# Development Tools
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0    # JavaScript runtime
make sop-add-package PACKAGE_NAME=vim VERSION=9.1.1700     # Text editor

# System Libraries  
make sop-add-package PACKAGE_NAME=libgmp VERSION=6.3.0-2   # Math library
make sop-add-package PACKAGE_NAME=pcre2 VERSION=10.46      # Regex library

# Core Utilities
make sop-add-package PACKAGE_NAME=coreutils VERSION=9.7-3  # Unix utilities
make sop-add-package PACKAGE_NAME=bash VERSION=5.3.3-1     # Shell

# Security
make sop-add-package PACKAGE_NAME=libandroid-selinux VERSION=14.0.0.11-1
```

### Manual Step Control (Advanced Users)

For debugging or manual control, individual SOP steps are available:
```bash
make sop-list LETTER=n                        # Step 1: List packages  
make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0  # Step 2: Download
make sop-extract PACKAGE_NAME=nodejs          # Step 3: Extract  
make sop-analyze PACKAGE_NAME=nodejs          # Step 4: Analyze
make sop-copy PACKAGE_NAME=nodejs             # Step 5: Copy files
make sop-update PACKAGE_NAME=nodejs           # Step 6: Update Java code
make sop-build                                # Step 7: Build & test
```

### Help & Reference
```bash
make sop-help                                 # Complete SOP documentation
make help                                     # General Makefile help
```

## Package Integration Examples

### Example 1: Complete Node.js Ecosystem (Mixed Native + Scripts)

```bash
# Complete automated integration
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0

# Analysis shows mixed file types:
# - node: ARM aarch64 ELF executable (native → jniLibs)
# - npm/npx: Scripts/symlinks (scripts → assets)
# - node_modules: Dependencies (scripts → assets)

# Result:
# - libnode.so: Native executable in jniLibs/arm64-v8a/
# - npm/npx: Scripts in assets/termux/usr/bin/
# - node_modules: Complete dependency tree in assets/termux/usr/lib/
# - TermuxInstaller.java: Only node executable needs entry
```

### Example 2: DPKG Package Management Suite

```bash
# Complete automated integration
make sop-add-package PACKAGE_NAME=dpkg VERSION=1.22.6-4

# Automated analysis identifies multiple utilities:
# - dpkg, dpkg-deb, dpkg-query, dpkg-split (all native)
# - All converted to lib*.so format automatically
# - TermuxInstaller.java entries generated for all executables

# Result:
# - All DPKG utilities available as native executables
# - Proper .so naming conventions applied
# - Complete package management suite integrated
```

### Example 3: Dependency Resolution (libandroid-support)

```bash
# Complete automated integration  
make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1

# Automated analysis identifies shared library:
# - libandroid-support.so: Runtime dependency (library → jniLibs)
# - Original .so name preserved
# - No TermuxInstaller.java entry needed (libraries handled automatically)

# Result:
# - Shared library available for native executables
# - Proper runtime dependency resolution
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
- **Runtime**: 
  - Base symlink: `/usr/lib/library.so` → `/data/app/{package}/lib/arm64/library.so`
  - Version symlinks: `/usr/lib/library.so.1` → `/usr/lib/library.so`
- **TermuxInstaller**: No entry needed, symlinks created automatically

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
# Use automated Makefile targets for reliable downloads
make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0
make sop-download PACKAGE_NAME=apt VERSION=2.8.1-2
make sop-download PACKAGE_NAME=dpkg VERSION=1.22.6-1

# Alternative: Download multiple packages with versions
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0    # Complete workflow
```

#### 2. Extract Native Binaries
```bash
# Automated extraction with complete package analysis
make sop-extract PACKAGE_NAME=nodejs
make extract-package PACKAGE_NAME=nodejs   # With control files

# View extraction results
make sop-analyze PACKAGE_NAME=nodejs
# Shows: Native binaries, scripts, dependencies, integration recommendations
```

#### 3. Convert to Android Native Libraries
```bash
# Automated conversion handling native/script file distinctions
make sop-copy PACKAGE_NAME=nodejs

# Automatically handles:
# - Native executables → jniLibs/arm64-v8a/lib*.so (node)
# - Scripts → assets/termux/usr/bin/ (npm, npx) 
# - Dependencies → assets/termux/usr/lib/ (node_modules)
# - Proper permissions set automatically
```

#### 4. Dependency Resolution
```bash
# Automated dependency analysis and integration
make sop-analyze PACKAGE_NAME=nodejs
# Shows required dependencies: libandroid-support, libc++_shared

# Integrate dependencies automatically
make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1

# Check for missing dependencies across all packages
make check-duplicates   # Also identifies dependency gaps
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

### Two-Tier Library Symlink Strategy

This approach creates a two-level symlink chain for shared libraries:

1. **Tier 1**: Base library symlinks in `/usr/lib/` point to actual files in `/data/app/.../lib/arm64/`
2. **Tier 2**: Version postfix symlinks within `/usr/lib/` point to base library symlinks in `/usr/lib/`

**Benefits:**
- Native libraries remain in secure read-only `/data/app` location  
- Standard library paths available in `/usr/lib/` for compatibility
- Version-specific library lookups supported (e.g., `libz.so.1`, `libcrypto.so.3`)
- Clean separation between Android's native library system and Unix conventions

**Symlink Chain Example:**
```
Application requests libz.so.1
↓
/usr/lib/libz.so.1 → /usr/lib/libz.so → /data/app/{hash}/lib/arm64/libz.so (actual file)
```

### Library Symlinks (`/usr/lib`) - Two-Tier Strategy
```bash
# Core libraries: Base symlinks point to /data/app (read-only native libraries)
/usr/lib/libandroid-glob.so -> /data/app/{hash}/lib/arm64/libandroid-glob.so
/usr/lib/libapt-private.so -> /data/app/{hash}/lib/arm64/libapt-private.so
/usr/lib/libapt-pkg.so -> /data/app/{hash}/lib/arm64/libapt-pkg.so

# Zlib with versioned symlinks for Node.js compatibility
/usr/lib/libz.so -> /data/app/{hash}/lib/arm64/libz.so
/usr/lib/libz.so.1 -> /usr/lib/libz.so          # Version symlink within /usr/lib
/usr/lib/libz.so.1.3.1 -> /usr/lib/libz.so      # Full version symlink within /usr/lib

# OpenSSL libraries with version symlinks
/usr/lib/libcrypto3.so -> /data/app/{hash}/lib/arm64/libcrypto3.so
/usr/lib/libcrypto.so.3 -> /usr/lib/libcrypto3.so
/usr/lib/libssl3.so -> /data/app/{hash}/lib/arm64/libssl3.so  
/usr/lib/libssl.so.3 -> /usr/lib/libssl3.so

# ICU libraries with version symlinks
/usr/lib/libicudata771.so -> /data/app/{hash}/lib/arm64/libicudata771.so
/usr/lib/libicudata.so.77.1 -> /usr/lib/libicudata771.so
/usr/lib/libicudata.so.77 -> /usr/lib/libicudata771.so
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

# 2. Package integration (automated SOP workflow - RECOMMENDED)
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0     # Complete integration
make sop-add-package PACKAGE_NAME=libandroid-support VERSION=29-1  # Dependencies
make sop-add-package PACKAGE_NAME=coreutils VERSION=9.7-3   # Unix utilities

# Alternative: Individual SOP steps (for debugging)
make sop-help        # Show all SOP automation options

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

### Automated SOP Integration

The Standard Operating Procedure has been completely automated through Makefile targets. All manual scripts have been replaced with reliable, consistent automation:

#### Core SOP Commands
```bash
# Complete package integration (all 7 SOP steps in one command)
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0
make sop-add-package PACKAGE_NAME=coreutils VERSION=9.7-3
make sop-add-package PACKAGE_NAME=libgmp VERSION=6.3.0-2

# Individual SOP step control for debugging
make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0  # Step 2: Download
make sop-extract PACKAGE_NAME=nodejs                  # Step 3: Extract
make sop-analyze PACKAGE_NAME=nodejs                  # Step 4: Analyze
make sop-copy PACKAGE_NAME=nodejs                     # Step 5: Copy files
make sop-update PACKAGE_NAME=nodejs                   # Step 6: Update Java
make sop-build                                        # Step 7: Build & test
```

#### Benefits of Makefile Automation
- **Consistency**: Identical process every time, eliminates human error
- **Error handling**: Automatic validation and rollback on failures  
- **Dependency management**: Automatic resolution of package dependencies
- **File type detection**: Automatic handling of native vs. script files
- **Version tracking**: Consistent naming and versioning across integrations
- **Documentation**: Built-in help system with `make sop-help`

#### Legacy Script Support
Individual scripts are maintained for educational purposes but **not recommended** for production use:
- Use `make sop-add-package` instead of manual scripts
- Scripts may be removed in future versions
- Makefile automation provides superior reliability and error handling

### Release Process
```bash
# Full release build with automated SOP integration
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0     # Latest packages
make sop-add-package PACKAGE_NAME=coreutils VERSION=9.7-3   # Core utilities
make sop-add-package PACKAGE_NAME=libgmp VERSION=6.3.0-2    # Math libraries

BUILD_TYPE=release make build     # Build release APK
make lint test                   # Final validation
make release                     # Complete release workflow
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