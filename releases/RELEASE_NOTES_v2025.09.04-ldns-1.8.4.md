# Termux AI v2025.09.04-ldns-1.8.4 Release Notes

## 🚀 New Features & Improvements

### DNS Infrastructure Upgrade
- **Updated ldns**: Upgraded from version 1.7.1-2 to 1.8.4-1
- **New `drill` command**: DNS lookup tool for diagnostics and queries
- **Better RFC support**: Enhanced support for recent and experimental DNS RFCs
- **OpenSSL v3 compatibility**: Fully compatible with modern SSL/TLS infrastructure

### Core System Libraries
- **termux-exec 1:2.3.0**: Essential execution environment with LD_PRELOAD support
- **libandroid-support 29-1**: Extended Android C library support
- **libandroid-glob 0.6-3**: Glob pattern matching functionality

### Development Tools
- **Node.js 24.7.0**: Latest LTS JavaScript runtime
- **npm & npx**: Package management for Node.js
- **GitHub CLI (gh) 2.78.0**: Command-line interface for GitHub
- **Git 2.23.0-1**: Version control system

### Networking & Security
- **curl 8.15.0-1** with full protocol support:
  - HTTP/HTTPS, FTP, SFTP protocols
  - libssh2 1.11.1-1 for SSH protocols
  - libnghttp2 1.67.0 for HTTP/2 support
  - libnghttp3 1.11.0-1 for HTTP/3 support
- **OpenSSL v3.5.2**: Modern cryptographic library
- **openssh 10.0p2-9**: Complete SSH suite (ssh, scp, sftp, ssh-keygen, etc.)
- **Kerberos (krb5) 1.17-2**: Authentication framework

### System Utilities
- **coreutils 9.7-3**: 100+ essential Unix commands
- **bash 5.3.3-1**: Advanced shell with modern features
- **vim 9.1.1700**: Powerful text editor
- **dpkg 1.22.6-4 & apt 2.8.1-2**: Package management system
- **which 2.23**: Command location utility

### Build System Improvements
- **Fixed Makefile URL paths**: Corrected package repository URLs
- **Enhanced SOP workflow**: Streamlined package integration process
- **Consistent repository structure**: termux-main for packages, termux-main-21 for metadata

## 📦 Package Details

### DNS Tools
- `drill`: DNS lookup utility (NEW in ldns 1.8.4-1)
- `ldns-config`: Library configuration script
- libldns.so: DNS programming library

### SSH Components
- `ssh`, `scp`, `sftp`: Secure file transfer and shell access
- `ssh-keygen`, `ssh-add`, `ssh-agent`: Key management
- `sshd`, `ssh-keyscan`: Server and scanning utilities

### Archive & Compression
- Support for tar, gzip, bzip2, xz, zstd formats
- Full archiving and extraction capabilities

## 🔧 Technical Improvements

### Architecture
- **ARM64-v8a optimized**: Native 64-bit ARM performance
- **OpenSSL v3 only**: Removed legacy SSL 1.1 compatibility (5MB smaller)
- **W^X compliance**: Proper execution permissions for Android

### Library Management
- **296 native libraries**: Comprehensive system library support  
- **Symbolic link management**: Proper version compatibility
- **LD_PRELOAD integration**: Correct execution environment via termux-exec

## 📊 Release Statistics

- **APK Size**: 236MB (optimized from 241MB)
- **Total Packages**: 40+ integrated Termux packages
- **Native Libraries**: 296 .so files
- **Executables**: 200+ Unix/Linux commands
- **Architecture**: Universal ARM64-v8a

## 🔍 Testing & Validation

- ✅ Core Unix commands functional
- ✅ Node.js runtime and npm working
- ✅ DNS resolution with drill command
- ✅ SSH connectivity and key generation
- ✅ Package management system operational
- ✅ File compression and archiving working
- ✅ Text editing with vim functional

## 📋 Installation

1. Download: `termux-app-v2025.09.04-ldns-1.8.4.apk`
2. Verify checksum: `termux-app-v2025.09.04-ldns-1.8.4.apk.sha256`
3. Install via ADB: `adb install termux-app-v2025.09.04-ldns-1.8.4.apk`
4. Grant permissions for full functionality

## 🏗️ Built With

- Android Gradle Plugin 8.7.2
- NDK 26.1.10909125
- Kotlin 1.9.22
- Java 17 (OpenJDK)
- Termux packages from termux-main repository

---

**Generated**: September 4, 2025  
**Build Type**: Release (minified, optimized)  
**Target SDK**: Android API 34  
**Min SDK**: Android API 24