# Termux AI: Bootstrap-Free Terminal with Native Codex Integration

A modern fork of `termux/termux-app` that eliminates traditional package bootstrapping in favor of direct native executable integration. This implementation places Codex AI tools in Android's read-only `/data/app` directory for W^X (Write XOR Execute) compliance and enhanced security.

**Key Innovation**: No bootstrap installation required - native executables are automatically extracted by Android to read-only system locations and accessed via shell aliases.

Important: This fork supports only aarch64 (ARM64, `arm64-v8a`). Other ABIs are not supported.

## Implementation Overview
- **Bootstrap-free architecture**: Eliminates traditional Termux package installation
- **Native executable integration**: Uses Android's `extractNativeLibs=true` mechanism  
- **Read-only security**: Executables reside in `/data/app/.../lib/arm64/` (system-managed, non-writable)
- **Direct access**: Shell aliases provide seamless command execution
- **Android 14+ compatibility**: Full support for latest Android security requirements

## Technical Architecture

### Native Library Integration
- **Packaging**: Codex executables packaged as `.so` files in `app/src/main/jniLibs/arm64-v8a/`
- **Extraction**: Android automatically extracts to `/data/app/{package}/lib/arm64/` (read-only)
- **Access**: Shell aliases in `~/.profile` point directly to native library paths
- **Security**: W^X compliant - executables in read-only system-managed location

### Bootstrap Replacement
Traditional Termux bootstrap process has been completely replaced:
```java
// Before: Complex zip extraction and package installation
// After: Simple native executable verification and alias setup
private static void installNativeExecutables(Activity activity) throws Exception {
    String nativeLibDir = activity.getApplicationInfo().nativeLibraryDir;
    // Verify extracted libraries exist
    // Create .profile with aliases
}
```

### Android Compatibility
- **minSdk**: 33 (Android 13)
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
1. **Build time**: Codex binaries copied to `app/src/main/jniLibs/arm64-v8a/` as `.so` files
2. **Install time**: Android extracts libraries to `/data/app/{hash}/lib/arm64/`
3. **First run**: App creates `~/.profile` with aliases pointing to extracted libraries
4. **Runtime**: Users execute `codex` and `codex-exec` via aliases

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

After app launch, the following commands are available via aliases:

- **`codex`**: AI CLI for interactive AI assistance
- **`codex-exec`**: Non-interactive AI command execution  

Example usage:
```bash
# Load aliases (auto-loaded in new shells)
source ~/.profile

# Get help
codex --help
codex-exec --help

# Use AI assistance  
codex "explain this command: ls -la"
codex exec "write a shell script to backup files"
```

## Alias Configuration

The app automatically creates `~/.profile` with direct aliases:
```bash
# Termux shell profile
export HOME=/data/data/com.termux/files/home
export PREFIX=/data/data/com.termux/files/usr

# Aliases for native executables in read-only /data/app location
alias codex='/data/app/{hash}/lib/arm64/libcodex.so'
alias codex-exec='/data/app/{hash}/lib/arm64/libcodex-exec.so'
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

### No Package Manager
- **Traditional Termux**: Uses `pkg install` with APT package manager
- **Termux AI**: Direct native executable integration, no package installation

### Simplified Environment  
- **PATH**: Only `/system/bin` (no app-private bin directory)
- **Executables**: Accessed via aliases to read-only native library locations
- **Dependencies**: Self-contained native binaries with minimal system dependencies

### Enhanced Security
- **Execution**: Read-only native libraries prevent runtime modification
- **Permissions**: Minimal permission set for AI functionality
- **Isolation**: Native executables run with app permissions and SELinux context

## Development Workflow

### Local Development
```bash
# Verify environment
make doctor           # Check tools (adb, gradlew)
make devices          # List connected devices  
make verify-abi       # Ensure device is ARM64

# Build and test
make build            # Build debug APK
make lint test        # Code quality checks
make install          # Install on device
make run             # Launch app
make logs            # Monitor logs

# Maintenance  
make clean           # Clean build outputs
make uninstall       # Remove from device
```

### Release Process
```bash
BUILD_TYPE=release make build    # Build release APK
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
source .profile
codex --help         # Should show AI CLI help
codex-exec --help    # Should show non-interactive help
```

### Build Verification
```bash
make lint test       # Code quality and unit tests
make verify-abi      # Ensure ARM64 device
make logs           # Monitor app behavior
```

## Known Limitations
- **No package manager**: Traditional `pkg install` not available
- **ARM64 only**: Other architectures not supported
- **Minimal environment**: Only system binaries in PATH
- **No Python runtime**: Codex executables are self-contained

## Project Status
✅ **Completed**:
- Bootstrap removal and native executable integration
- Android 14+ compatibility (foreground services, receivers)
- Read-only `/data/app` placement with W^X compliance
- Shell alias configuration for seamless access
- Makefile build system with ARM64 verification

🎯 **Current Implementation**:
- Native Codex CLI available immediately after app launch
- No internet required for core AI functionality  
- Secure read-only executable placement
- Compatible with latest Android security policies

## License
Follows upstream Termux licensing. See individual component licenses for native binaries.