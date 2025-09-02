# Scripts Directory

This directory contains standalone scripts for Termux AI development and testing.

## Available Scripts

### `sop-user-test.sh`
Automated UI testing script that simulates user interactions with the Termux AI app via ADB input commands.

**Features:**
- Launches Termux AI app automatically
- Simulates real user typing using `adb input` commands  
- Redirects stdout/stderr to log file for result verification
- Uses `adb cat` to retrieve and display command outputs
- Tests 10 different command scenarios with logging
- Provides colorized output and progress feedback
- Creates persistent log file for later analysis
- Supports custom app ID configuration

**Usage:**
```bash
# Run with default settings
./scripts/sop-user-test.sh

# Use custom app ID
./scripts/sop-user-test.sh --app-id com.my.termux

# Set via environment variable
APP_ID=com.my.app ./scripts/sop-user-test.sh

# Show help
./scripts/sop-user-test.sh --help

# View log file after test
adb shell run-as com.termux cat /data/data/com.termux/files/home/sop-test.log
```

**Requirements:**
- Android device connected via ADB
- Termux AI app installed on device
- ADB in PATH
- App must have proper file system access

**Test Coverage:**
- Environment setup and PATH verification
- Node.js ecosystem (node, npm, npx)
- AI tools availability (codex commands)
- Package management (apt)
- Symbolic link validation
- Library dependency checking

**Integration:**
This script is called by the Makefile target `sop-user-test`:
```bash
make sop-user-test
```

## Script Development Guidelines

When adding new scripts to this directory:

1. **Make them executable**: `chmod +x script-name.sh`
2. **Add shebang**: Start with `#!/bin/bash`
3. **Include help option**: Support `-h` or `--help`
4. **Use proper error handling**: `set -e` and check prerequisites
5. **Add colorized output**: Use consistent color scheme
6. **Document in this README**: Add description and usage examples
7. **Update Makefile**: Add corresponding target if needed

## Directory Structure

```
scripts/
├── README.md              # This file
├── sop-user-test.sh      # Automated UI testing script
└── (future scripts...)
```

## Environment Variables

Scripts in this directory should support these standard environment variables:

- `APP_ID`: Application package ID (default: com.termux)
- `MAIN_ACTIVITY`: Main activity class (default: com.termux.app.TermuxActivity)
- `BUILD_TYPE`: Build type (debug/release)

## Error Handling

All scripts should:
- Check prerequisites (ADB, device connection, etc.)
- Provide clear error messages
- Exit with appropriate exit codes
- Handle failures gracefully