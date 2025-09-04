# Termux AI Release Deployment Summary

## Available Releases

### termux-app-v2025.09.04-ldns-1.8.4 (LATEST)
- **File**: termux-app-v2025.09.04-ldns-1.8.4.apk
- **Size**: 236MB
- **Features**: Updated ldns 1.8.4-1 with drill command, termux-exec integration
- **SHA256**: `$(cat releases/termux-app-v2025.09.04-ldns-1.8.4.apk.sha256 | cut -d' ' -f1)`
- **Release Notes**: [RELEASE_NOTES_v2025.09.04-ldns-1.8.4.md](RELEASE_NOTES_v2025.09.04-ldns-1.8.4.md)

### termux-app-v2025.09.04-ssl3-only
- **File**: termux-app-v2025.09.04-ssl3-only.apk  
- **Size**: 236MB
- **Features**: OpenSSL v3 only, removed legacy SSL 1.1 compatibility
- **SHA256**: `$(cat releases/termux-app-v2025.09.04-ssl3-only.apk.sha256 | cut -d' ' -f1)`

### termux-app-v2025.09.04-unified
- **File**: termux-app-v2025.09.04-unified.apk
- **Size**: 241MB  
- **Features**: Initial comprehensive package integration
- **SHA256**: `$(cat releases/termux-app-v2025.09.04-unified.apk.sha256 | cut -d' ' -f1)`

## Deployment Instructions

### Via ADB
```bash
# Install latest release
adb install releases/termux-app-v2025.09.04-ldns-1.8.4.apk

# Grant essential permissions
adb shell pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE
adb shell pm grant com.termux android.permission.POST_NOTIFICATIONS

# Add to battery optimization whitelist
adb shell dumpsys deviceidle whitelist +com.termux
```

### Manual Installation
1. Transfer APK to Android device
2. Enable "Install from unknown sources"
3. Install APK via file manager
4. Launch Termux and grant permissions when prompted

## Verification

### Checksum Verification
```bash
# On macOS/Linux
shasum -a 256 termux-app-v2025.09.04-ldns-1.8.4.apk

# Compare with provided SHA256 hash
```

### Functionality Tests
```bash
# Test basic commands
whoami
pwd
ls

# Test Node.js
node --version
npm --version

# Test DNS tools (NEW)
drill google.com
ldns-config --version

# Test SSH
ssh-keygen -t rsa -f test_key -N ""
ssh -V

# Test package management
apt --version
which curl
```

## Rollback Instructions

If issues occur with the latest release, install a previous version:

```bash
# Install SSL3-only version
adb install releases/termux-app-v2025.09.04-ssl3-only.apk

# Or install unified version
adb install releases/termux-app-v2025.09.04-unified.apk
```

---
**Last Updated**: September 4, 2025  
**Deployment Status**: Ready for production  
**Recommended Version**: v2025.09.04-ldns-1.8.4