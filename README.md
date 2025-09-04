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
npm --version          # Package manager v11.5.1
git --version          # Version control v2.51.0
gh --version           # GitHub CLI v2.78.0
codex --help           # AI CLI assistance
apt --version          # Package management v2.8.1
curl --version         # Data transfer tool v8.15.0
ls /usr/bin            # 296+ available commands
```

## 🏗 Architecture Overview

### Bootstrap-Free Design
- **Traditional Termux**: Complex zip extraction and package installation
- **Termux AI**: Native executable verification and symbolic link creation
- **Benefits**: Faster startup, better security, W^X compliance

### Unified Executable Integration Process
1. **ALL executables** (binaries + scripts) → placed in `jniLibs/arm64-v8a/` as `.so` files
2. **Android** automatically extracts to `/data/app/.../lib/arm64/` (read-only)
3. **Symbolic links** in `/usr/bin` point to native library paths uniformly
4. **Scripts** (npm, npx, corepack) handled identically to native binaries
5. **Dependencies** (node_modules) available in `/usr/lib`

### Security & Compliance
- **W^X Policy**: Executables in read-only `/data/app` system location
- **SELinux Compatible**: Uses Android's native library extraction mechanism
- **Android 14+**: Full support with foreground service permissions

## 📦 Included Software

### Core Development Tools

| Component | Version | Description |
|-----------|---------|-------------|
| **Node.js** | v24.7.0 | JavaScript runtime with V8 engine |
| **npm** | v11.5.1 | Node.js package manager |
| **npx** | Latest | Package executor for Node.js |
| **Git** | v2.51.0 | Distributed version control system |
| **GitHub CLI** | v2.78.0 | GitHub integration and automation |
| **Vim** | v9.1.1700 | Advanced text editor |
| **Bash** | v5.3.3-1 | GNU Bourne Again Shell |

### AI & Automation

| Component | Version | Description |
|-----------|---------|-------------|
| **Codex CLI** | v0.25.0 | AI-powered CLI assistant |
| **Codex-Exec** | v0.25.0 | Non-interactive AI command execution |

### Package Management

| Component | Version | Description |
|-----------|---------|-------------|
| **APT** | v2.8.1-2 | Advanced Package Tool |
| **DPKG** | v1.22.6-4 | Debian package management system |
| **Core Utils** | v9.7-3 | GNU core utilities (100+ commands) |

### Network & Security

| Component | Version | Description |
|-----------|---------|-------------|
| **OpenSSH** | v10.0p2-9 | Secure shell client and server |
| **curl** | v8.15.0-1 | Command-line data transfer tool |
| **OpenSSL** | v3.5.2 | Cryptography and SSL/TLS toolkit |
| **DNS Utils** | v9.20.12 | BIND DNS tools (dig, nslookup, host) |
| **CA Certificates** | 2025.08.12 | Mozilla CA certificate bundle (146 certs) |
| **Less** | v679-2 | Terminal pager for viewing text files |

### System Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| **libicu** | v77.1-1 | Unicode and localization support |
| **libxml2** | v2.14.5-1 | XML parsing library |
| **libcurl** | v8.15.0-1 | Data transfer library |
| **libsqlite** | v3.50.4-1 | SQL database engine |
| **libgcrypt** | v1.11.2-1 | Cryptographic library |
| **pcre2** | v10.46 | Perl-compatible regular expressions |
| **ncurses** | v6.5.20240831-3 | Terminal control library |
| **readline** | v8.3.1-1 | Command-line editing library |
| **zlib** | v1.3.1-1 | Compression library |
| **libiconv** | v1.18-1 | Character encoding conversion |
| **json-c** | v0.18-1 | JSON parsing library |

### Complete Package List (47 packages, 500MB)

<details>
<summary>Click to view all packages</summary>

- android-codex-cli-0.25.0
- apt_2.8.1-2
- bash_5.3.3-1
- bzip2_1.0.8-8
- c-ares_1.34.5
- ca-certificates_1:2025.08.12
- coreutils_9.7-3
- curl_8.15.0-1
- dnsutils_9.20.12
- dpkg_1.22.6-4
- gh_2.78.0
- git_2.51.0
- json-c_0.18-1
- krb5_1.17-2
- ldns_1.8.4-1
- less_679-2
- libandroid-execinfo_0.1-3
- libandroid-glob_0.6-3
- libandroid-selinux_14.0.0.11-1
- libandroid-support_29-1
- libbz2_1.0.8-8
- libc++_28c
- libcurl_8.15.0-1
- libgcrypt_1.11.2-1
- libgmp_6.3.0-2
- libgpg-error_1.55-1
- libiconv_1.18-1
- libicu_77.1-1
- liblzma_5.8.1-1
- libnghttp2_1.67.0
- libnghttp3_1.11.0-1
- libsqlite_3.50.4-1
- libssh2_1.11.1-1
- libxml2_2.14.5-1
- ncurses_6.5.20240831-3
- nodejs_24.7.0
- openssh_10.0p2-9
- openssl_1:3.5.2
- pcre2_10.46
- readline_8.3.1-1
- resolv-conf_1.3
- termux-exec_1:2.3.0
- vim_9.1.1700
- which_2.23
- xz-utils_5.8.1-1
- zlib_1.3.1-1
- zstd_1.5.7-1

</details>

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

#### Resolving Missing Libraries
When encountering missing library errors (e.g., "library libcharset.so not found"):

1. **Find the package containing the library**:
   ```bash
   grep "libcharset.so" packages/Contents-aarch64
   # Output: usr/lib/libcharset.so libiconv
   ```

2. **Download and extract the required package**:
   ```bash
   make sop-download PACKAGE_NAME=libiconv VERSION=1.18-1
   make sop-extract PACKAGE_NAME=libiconv
   ```

3. **Copy the library to jniLibs**:
   ```bash
   cp packages/libiconv-extract/.../lib/libcharset.so \
      app/src/main/jniLibs/arm64-v8a/
   ```

4. **Update TermuxInstaller.java** to include the library in baseLibraries array
5. **Rebuild and test**

#### Complete Example: Adding Git
```bash
# 1. Download git package
wget -O packages/git_2.23.0-1_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main-21/pool/main/g/git/git_2.23.0-1_aarch64.deb"

# 2. Extract and copy main executable
dpkg-deb -x packages/git_2.23.0-1_aarch64.deb packages/git-extract
cp packages/git-extract/.../libexec/git-core/git \
   app/src/main/jniLibs/arm64-v8a/libgit.so

# 3. Check for missing libraries at runtime
# Error: "library libcharset.so not found"

# 4. Find which package contains libcharset.so
grep "lib/libcharset.so" packages/Contents-aarch64
# Result: data/.../usr/lib/libcharset.so libiconv

# 5. Download and add missing dependency
wget -O packages/libiconv_1.18-1_aarch64.deb \
  "https://packages.termux.dev/apt/termux-main-21/pool/main/libi/libiconv/libiconv_1.18-1_aarch64.deb"
dpkg-deb -x packages/libiconv_1.18-1_aarch64.deb packages/libiconv-extract
cp packages/libiconv-extract/.../lib/libcharset.so app/src/main/jniLibs/arm64-v8a/
cp packages/libiconv-extract/.../lib/libiconv.so app/src/main/jniLibs/arm64-v8a/

# 6. Update TermuxInstaller.java
# Add: {"libgit.so", "git"} to executables array
# Add: "libcharset.so", "libiconv.so" to baseLibraries array

# 7. Build and test
make build && make install && make run
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
- **Script Files** (npm, npx): `jniLibs/arm64-v8a/libscript.so`
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
├── bin/                               # All symlinks to /data/app
│   ├── node -> /data/app/.../lib/arm64/libnode.so
│   ├── npm -> /data/app/.../lib/arm64/libnpm.so
│   ├── git -> /data/app/.../lib/arm64/libgit.so
│   └── gh -> /data/app/.../lib/arm64/libgh.so
└── lib/                              # Libraries + node_modules from assets
```

### Environment Customization
The `.profile` automatically sources `/data/local/tmp/android_sourceme` if it exists, allowing for custom environment setup:

```bash
# Place custom configuration in /data/local/tmp/android_sourceme
adb shell "echo 'export CUSTOM_VAR=value' > /data/local/tmp/android_sourceme"

# The file will be automatically sourced on app launch
# See examples/android_sourceme_example.sh for configuration ideas
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
- **`git`**: Version control system with full Git functionality
- **`gh`**: GitHub CLI for repository management and automation

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
- **Unified Approach**: All executables (binaries + scripts) as .so files in jniLibs

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