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
**IMPORTANT**: Android requires all native executables to end with `.so` extension and be placed in the `jniLibs` directory.

- **Android Requirement**: Native executables MUST be named as `lib*.so` files
  - Android only extracts files matching the pattern `lib*.so` from APK
  - Files are extracted to `/data/app/{package_hash}/lib/arm64/lib*.so`
  - This is a hard requirement enforced by Android's package manager
  
- **Source**: Native ARM64 binaries from packages.termux.dev Debian packages
- **Extraction**: `.deb` packages extracted using `ar` and `tar` to obtain native binaries
- **Conversion**: Binaries renamed to follow `lib*.so` naming convention:
  - AI tools: `libcodex.so`, `libcodex-exec.so` (custom Codex binaries)
  - Package management: `libapt.so` (from apt_2.8.1-2_aarch64.deb), `libdpkg.so`
  - Development runtime: `libnode.so` (from nodejs_24.7.0_aarch64.deb)
  - Core utilities: Must be named as `lib*.so` (e.g., `libcat.so`, `libls.so`)
  
- **APK Integration**: Gradle packages `.so` files into APK with `extractNativeLibs=true`
- **System Extraction**: Android extracts ONLY `lib*.so` files to `/data/app/{hash}/lib/arm64/`
- **Access**: Symbolic links in `/usr/bin` remove the `lib` prefix and `.so` suffix for natural command names
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

**Critical**: Android's package manager ONLY extracts files matching `lib*.so` pattern from APK.

```bash
# Copy binaries and rename following Android's lib*.so naming requirement
mkdir -p app/src/main/jniLibs/arm64-v8a/

# IMPORTANT: All files MUST follow lib*.so naming convention
# Original binary name -> Android library name
# node -> libnode.so
# apt -> libapt.so
# cat -> libcat.so

# Node.js ecosystem
cp native-binaries/data/data/com.termux/files/usr/bin/node app/src/main/jniLibs/arm64-v8a/libnode.so
cp native-binaries/data/data/com.termux/files/usr/bin/npm app/src/main/jniLibs/arm64-v8a/libnpm.so  
cp native-binaries/data/data/com.termux/files/usr/bin/npx app/src/main/jniLibs/arm64-v8a/libnpx.so

# Package management
cp native-binaries/data/data/com.termux/files/usr/bin/apt app/src/main/jniLibs/arm64-v8a/libapt.so
cp native-binaries/data/data/com.termux/files/usr/bin/dpkg app/src/main/jniLibs/arm64-v8a/libdpkg.so

# Verify executable permissions
chmod +x app/src/main/jniLibs/arm64-v8a/*.so

# Note: Files not matching lib*.so pattern will NOT be extracted by Android
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

The app automatically creates a comprehensive symbolic link system that transforms Android's `lib*.so` naming back to natural command names:

### Naming Transformation
Android requires `lib*.so` naming, but users expect natural command names. The symlink system handles this:
- **APK contains**: `libnode.so`, `libapt.so`, `libcodex.so`
- **Android extracts to**: `/data/app/{hash}/lib/arm64/lib*.so`
- **Symlinks created as**: `/usr/bin/node`, `/usr/bin/apt`, `/usr/bin/codex`

### Executable Symlinks (`/usr/bin`)
```bash
# AI Tools (lib prefix and .so suffix removed)
/usr/bin/codex -> /data/app/{hash}/lib/arm64/libcodex.so
/usr/bin/codex-exec -> /data/app/{hash}/lib/arm64/libcodex-exec.so

# Package Management (natural command names)
/usr/bin/apt -> /data/app/{hash}/lib/arm64/libapt.so
/usr/bin/node -> /data/app/{hash}/lib/arm64/libnode.so
/usr/bin/npm -> /data/app/{hash}/lib/arm64/libnpm.so
/usr/bin/npx -> /data/app/{hash}/lib/arm64/libnpx.so
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

# 2. Native package integration (first time setup)
./scripts/download-packages.sh   # Download .deb packages from packages.termux.dev
./scripts/extract-natives.sh     # Extract binaries and convert to .so files
./scripts/resolve-deps.sh         # Include runtime dependencies

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