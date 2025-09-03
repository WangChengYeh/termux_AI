# Termux AI: Bootstrap-Free Terminal with Native Codex Integration

A modern fork of `termux/termux-app` that eliminates traditional package bootstrapping in favor of direct native executable integration. This implementation places AI tools and development environments in Android's read-only `/data/app` directory for W^X compliance and enhanced security.

**Key Innovation**: No bootstrap installation required - native executables are automatically extracted by Android to read-only system locations and accessed via symbolic links.

![Termux AI in action](termux_ai_screenshot.png)
*Termux AI running with Node.js v24.7.0 and AI assistance*

## 🚀 Quick Start

### Requirements
- **Android**: 14+ (API level 34+)
- **Architecture**: ARM64 (`arm64-v8a`) devices only
- **Storage**: ~74MB APK with complete Node.js ecosystem

### Installation
1. Download APK from [Releases](../../releases)
2. Install on ARM64 Android device  
3. Launch app - all executables configured automatically
4. Ready for development and AI assistance

### Immediate Usage
```bash
node --version         # Node.js v24.7.0
npm --version          # Package manager
codex --help           # AI CLI assistance
apt --version          # Package management
ls /usr/bin            # 80+ available commands
```

## 🏗 Architecture Overview

### Bootstrap-Free Design
- **Traditional Termux**: Complex zip extraction and package installation
- **Termux AI**: Native executable verification and symbolic link creation
- **Benefits**: Faster startup, better security, W^X compliance

### Native Integration Process
1. **ARM64 binaries** from packages.termux.dev → extracted as `.so` files
2. **Android** automatically extracts to `/data/app/.../lib/arm64/` (read-only)
3. **Symbolic links** in `/usr/bin` point to native library paths  
4. **Script files** (npm, npx) extracted from assets to `/usr/bin`
5. **Dependencies** (node_modules) available in `/usr/lib`

### Security & Compliance
- **W^X Policy**: Executables in read-only `/data/app` system location
- **SELinux Compatible**: Uses Android's native library extraction mechanism
- **Android 14+**: Full support with foreground service permissions

## 📦 Included Software

| Component | Version | Type | Description |
|-----------|---------|------|-------------|
| **Node.js** | v24.7.0 | Native | JavaScript runtime |
| **npm** | v11.5.1 | Script | Package manager |
| **npx** | Latest | Script | Package executor |
| **Codex CLI** | Latest | Native | AI assistance |
| **APT** | v2.8.1 | Native | Package management |
| **Core Utils** | v9.7-3 | Native | Unix commands (cat, ls, bash, vim, etc.) |
| **DPKG Suite** | v1.22.6 | Native | Debian package tools |

## 🛠 Development Workflow

### Package Integration (SOP)
The Standard Operating Procedure has been automated through Makefile targets:

```bash
# Complete package integration (recommended)
make sop-add-package PACKAGE_NAME=nodejs VERSION=24.7.0

# Individual steps for debugging
make sop-list LETTER=n                # List packages
make sop-download PACKAGE_NAME=nodejs VERSION=24.7.0
make sop-extract PACKAGE_NAME=nodejs  # Extract package
make sop-analyze PACKAGE_NAME=nodejs  # Analyze structure
make sop-copy PACKAGE_NAME=nodejs     # Copy to Android structure
make sop-update PACKAGE_NAME=nodejs   # Update Java code
make sop-build                        # Build and test
```

### Build & Deploy
```bash
# Development build
make doctor          # Verify environment
make build           # Build debug APK
make install         # Install with permissions
make run            # Launch app

# Production release
BUILD_TYPE=release make build
make github-release  # Automated GitHub release
```

### Integration Rules
- **Native Executables** (ARM64 ELF): `jniLibs/arm64-v8a/libname.so`
- **Script Files** (npm, npx): `assets/termux/usr/bin/script`
- **Shared Libraries**: `jniLibs/arm64-v8a/library.so` (keep original name)
- **Dependencies**: `assets/termux/usr/lib/` (node_modules, etc.)

## 🔧 Technical Details

### Project Structure
```
├── packages/                          # Downloaded .deb packages
├── app/src/main/jniLibs/arm64-v8a/   # Native executables as .so files
├── app/src/main/assets/termux/        # Scripts and dependencies
└── app/src/main/java/.../TermuxInstaller.java  # Symlink creation
```

### Runtime Environment
```
/data/data/com.termux/files/usr/
├── bin/                               # Mixed: symlinks + scripts
│   ├── node -> /data/app/.../lib/arm64/libnode.so (native)
│   ├── npm                            # Script from assets
│   └── npx                            # Script from assets
└── lib/                              # Libraries + node_modules from assets
```

### Key Modifications
- **`TermuxInstaller.java`**: Replaced bootstrap with native executable verification
- **`TermuxShellEnvironment.java`**: Simplified PATH to `/system/bin` only
- **`AndroidManifest.xml`**: Android 14+ foreground service permissions
- **`TermuxActivity.java`**: Fixed broadcast receiver export flags

## 📋 Available Commands

### AI & Development
- **`codex`**: Interactive AI CLI assistance
- **`codex-exec`**: Non-interactive AI command execution
- **`node`**: JavaScript runtime and development
- **`npm`**, **`npx`**: Complete Node.js package ecosystem

### System & Package Management
- **`apt`**, **`pkg`**: Package management for additional software
- **`dpkg`** suite: Debian package utilities
- **Core utilities**: cat, ls, echo, pwd, bash, vim, and 70+ more commands

## 🧪 Testing & Verification

### Automated Testing
```bash
make sop-user-test   # Automated UI testing via ADB
make sop-test        # Interactive command testing
make logs           # Monitor app behavior
```

### Manual Verification
```bash
# Connect to running app
adb shell run-as com.termux
cd /data/data/com.termux/files/home

# Test functionality
node --version      # Should show v24.7.0
npm --version       # Should show v11.5.1  
codex --help        # Should show AI CLI help
ls /usr/bin         # Should list all available commands
```

## ⚠️ Known Limitations

- **Architecture**: ARM64 (`arm64-v8a`) devices only
- **Android Version**: Requires API level 34+ (Android 14+)
- **Package Scope**: Essential packages included; use APT for additional software
- **npm/npx Issues**: Script execution permissions under investigation

## 📈 Project Status

**✅ Completed Core Features:**
- Bootstrap-free Node.js v24.7.0 integration
- Native library W^X compliance and Android 14+ compatibility
- Automated package integration workflow (SOP)
- Complete development environment with AI tools
- Hybrid package management (native + APT)

**🚀 Ready for Production:**
- Stable release builds with R8 optimization
- Comprehensive testing and verification
- Automated GitHub release workflow
- Full documentation and development guides

## 📖 Additional Resources

- **SOP Documentation**: Run `make sop-help` for complete package integration guide
- **Build System**: Run `make help` for all available commands
- **GitHub Releases**: Automated via `make github-release` 
- **Issue Tracking**: Report problems via GitHub Issues

## 📄 License

Follows upstream Termux licensing. See individual component licenses for native binaries.

---

**Ready to develop?** Download the latest release and start coding with Node.js v24.7.0 and AI assistance immediately!