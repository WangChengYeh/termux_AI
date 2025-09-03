# Termux AI Scripts

This directory contains utility scripts for building and releasing Termux AI.

## GitHub Release Script

The `github-release.sh` script automates the process of creating production builds and GitHub releases.

### Features

- **Auto-versioning**: Automatically increments version numbers based on the latest release
- **Production builds**: Creates optimized R8 release APKs
- **GitHub integration**: Automatically creates releases with detailed notes
- **Prerequisite checks**: Verifies GitHub CLI authentication and required tools
- **Dry run support**: Build APKs without creating releases for testing
- **Flexible configuration**: Support for custom versions, titles, and release notes

### Prerequisites

1. **GitHub CLI**: Install and authenticate
   ```bash
   # Install GitHub CLI
   brew install gh          # macOS
   sudo apt install gh      # Ubuntu
   
   # Authenticate
   gh auth login
   
   # Add workflow scope for releases
   gh auth refresh -h github.com -s workflow
   ```

2. **Android development environment**: Set up for Termux AI building
   - Android SDK and NDK
   - Gradle and build tools
   - ARM64 development setup

### Usage

#### Basic Usage (Recommended)

```bash
# Auto-increment version and create release
make github-release-script

# Or run directly
./scripts/github-release.sh
```

This will:
1. Auto-detect the next version number (e.g., v1.7.0 → v1.8.0)
2. Build a production release APK
3. Create a GitHub release with standard notes

#### Advanced Usage

```bash
# Specify custom version
./scripts/github-release.sh -v v2.0.0 -t "Major Release"

# Add custom release notes
./scripts/github-release.sh -v v1.8.1 -c "- Fixed critical Git integration bug
- Updated Node.js dependencies
- Improved performance"

# Dry run (build APK but don't create release)
make github-release-script-dry-run
./scripts/github-release.sh --dry-run
```

#### Command Line Options

- `-v, --version VERSION`: Specify version tag (e.g., v1.8.0)
- `-t, --title TITLE`: Specify release title
- `-c, --changes CHANGES`: Specify what's new in this release
- `-d, --dry-run`: Build APK but don't create release
- `-h, --help`: Show help message

### Release Notes Template

The script automatically generates comprehensive release notes including:

- **Release highlights** with key features
- **Quick install instructions** for users
- **What's new** section with your custom changes
- **Release info** with APK size and target platform
- **Quick commands** for common tasks
- **Included software** overview
- **Documentation links**

### Examples

#### Standard Release
```bash
./scripts/github-release.sh
# Creates: v1.8.0 with auto-generated notes
```

#### Bug Fix Release
```bash
./scripts/github-release.sh -v v1.7.1 -t "Bug Fix Release" -c "- Fixed APT package installation issue
- Resolved symbolic link problems  
- Updated security patches"
```

#### Major Release
```bash
./scripts/github-release.sh -v v2.0.0 -t "Major Architecture Update" -c "- Redesigned unified executable architecture
- Added Python 3.11 integration
- Enhanced AI capabilities with GPT-4 support
- Breaking: Updated minimum Android version to 15+"
```

#### Development Testing
```bash
# Build APK for testing without creating release
./scripts/github-release.sh --dry-run
```

### Troubleshooting

#### Authentication Issues
```bash
# Check GitHub CLI status
gh auth status

# Re-authenticate with workflow scope
gh auth refresh -h github.com -s workflow
```

#### Build Failures
```bash
# Clean build environment
make clean

# Check prerequisites
make doctor

# Verify jniLibs structure
make check-jnilibs
```

#### Version Conflicts
```bash
# List existing releases
gh release list --repo WangChengYeh/termux_AI

# Delete a tag if needed (careful!)
git tag -d v1.8.0
git push origin --delete v1.8.0
```

### Integration with CI/CD

The script can be integrated into GitHub Actions or other CI/CD systems:

```yaml
# Example GitHub Actions workflow
- name: Create Release
  run: ./scripts/github-release.sh -v ${{ github.ref_name }}
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Output

Successful execution produces:
- **Production APK**: `app/build/outputs/apk/release/termux-app_apt-android-7-release_universal.apk`
- **GitHub Release**: Public release with APK attachment
- **Release URL**: Direct link to the created release

The script provides colored output with clear success/error indicators and progress tracking throughout the process.

## Other Scripts

### sop-user-test.sh
Automated UI testing for package integration verification.

### test-*.sh
Various testing scripts for development and quality assurance.

## Contributing

When adding new scripts:

1. Make them executable: `chmod +x script-name.sh`
2. Include proper error handling with `set -e`
3. Add help documentation with `-h/--help` flag
4. Use colored output for better user experience
5. Document the script in this README
6. Test thoroughly before committing