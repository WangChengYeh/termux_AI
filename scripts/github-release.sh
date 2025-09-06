#!/bin/bash

# GitHub Release Script for Termux AI
# Creates production builds and deploys to GitHub releases

set -e  # Exit on any error

# Configuration
REPO="WangChengYeh/termux_AI"
DEFAULT_VERSION_PREFIX="v1."
APK_PATH="app/build/outputs/apk/release/termux-app_apt-android-7-release_universal.apk"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI (gh) is not installed"
        echo "Install with: brew install gh (macOS) or apt install gh (Ubuntu)"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub CLI is not authenticated"
        echo "Run: gh auth login"
        exit 1
    fi
    
    # Check if we have the right scopes
    if ! gh auth status 2>&1 | grep -q "workflow"; then
        log_warning "GitHub CLI may need workflow scope for releases"
        echo "Run: gh auth refresh -h github.com -s workflow"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Prerequisites checked"
}

# Function to get the next version number
get_next_version() {
    log_info "Determining next version number..."
    
    # Get the latest release version
    latest_version=$(gh release list --repo "$REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")
    
    if [ -z "$latest_version" ]; then
        echo "${DEFAULT_VERSION_PREFIX}1.0"
        return
    fi
    
    # Extract version components
    if [[ $latest_version =~ ^v([0-9]+)\.([0-9]+)$ ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        next_minor=$((minor + 1))
        echo "v${major}.${next_minor}"
    else
        log_warning "Cannot parse version '$latest_version', using manual input"
        # Use environment variable if available, otherwise default to next patch version
        if [ -n "$RELEASE_VERSION" ]; then
            echo "$RELEASE_VERSION"
        else
            # Default to incrementing patch version (v1.8.0 -> v1.9.0)
            echo "v1.9.0"
        fi
    fi
}

# Function to generate release notes
generate_release_notes() {
    local version="$1"
    local changes="$2"
    
    cat << EOF
Bootstrap-free terminal with native Node.js v24.7.0, Git v2.23.0, and AI integration. No package installation required - ready for development immediately.

## ✨ Release Highlights
- **Instant Setup**: Download, install, develop - no bootstrap required
- **Native Performance**: Node.js and Git as ARM64 libraries with W^X compliance
- **AI Integration**: Built-in Codex CLI for development assistance
- **Enhanced SOP**: Automated dependency resolution for easy package integration

## 📱 Quick Install
1. Download APK below → Install on ARM64 Android 14+ device → Launch → Start coding

## 🚀 What's New in This Release
$changes

## 🔐 Release Info
- **Size**: $(ls -lh "$APK_PATH" 2>/dev/null | awk '{print $5}' || echo "N/A") | **Target**: ARM64 Android 14+ | **Build**: R8 Optimized

## 📚 Quick Commands
\`\`\`bash
# Development Environment
node --version        # v24.7.0 JavaScript runtime  
git --version         # v2.23.0 version control
npm --version         # v11.5.1 package manager
codex --help          # AI assistance

# Package Integration
make sop-find-lib LIBRARY=libssl.so     # Find dependency packages
make sop-add-package PACKAGE_NAME=vim   # Add new packages
ls /usr/bin           # 80+ available commands
\`\`\`

## 🚀 Included Software
**Development:** Node.js v24.7.0, npm, npx, Git v2.23.0 | **AI Tools:** Codex CLI/exec | **System:** APT, DPKG, Core Utils, Vim

## 📖 Documentation
[Complete README](https://github.com/$REPO/blob/master/README.md) - Architecture, SOP workflow, and technical details
EOF
}

# Function to build release APK
build_release() {
    log_info "Building production release APK..."
    
    # Clean previous builds
    BUILD_TYPE=release make clean
    log_success "Previous builds cleaned"
    
    # Build release APK
    BUILD_TYPE=release make build
    
    # Verify APK was created
    if [ ! -f "$APK_PATH" ]; then
        log_error "Release APK not found at: $APK_PATH"
        exit 1
    fi
    
    local apk_size=$(ls -lh "$APK_PATH" | awk '{print $5}')
    log_success "Release APK built successfully ($apk_size)"
}

# Function to create GitHub release
create_github_release() {
    local version="$1"
    local title="$2"
    local notes="$3"
    
    log_info "Creating GitHub release $version..."
    
    # Create the release
    local release_url
    release_url=$(gh release create "$version" "$APK_PATH" \
        --repo "$REPO" \
        --title "$title" \
        --notes "$notes" \
        2>&1)
    
    if [ $? -eq 0 ]; then
        log_success "Release created successfully!"
        echo "Release URL: $release_url"
    else
        log_error "Failed to create release: $release_url"
        exit 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
GitHub Release Script for Termux AI

Usage: $0 [OPTIONS]

Options:
    -v, --version VERSION    Specify version tag (e.g., v1.8.0)
    -t, --title TITLE        Specify release title
    -c, --changes CHANGES    Specify what's new in this release
    -d, --dry-run           Build APK but don't create release
    -h, --help              Show this help message

Examples:
    $0                                    # Auto-increment version
    $0 -v v1.8.0 -t "Bug Fix Release"    # Specify version and title
    $0 -d                                 # Dry run (build only)

If no options are provided, the script will:
1. Auto-increment the version number
2. Build a production release APK
3. Create a GitHub release with standard notes
EOF
}

# Main function
main() {
    local version=""
    local title=""
    local changes=""
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                version="$2"
                shift 2
                ;;
            -t|--title)
                title="$2"
                shift 2
                ;;
            -c|--changes)
                changes="$2"
                shift 2
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # Get version if not specified
    if [ -z "$version" ]; then
        version=$(get_next_version)
    fi
    
    # Set default title if not specified
    if [ -z "$title" ]; then
        title="Termux AI $version - Production Release"
    fi
    
    # Set default changes if not specified
    if [ -z "$changes" ]; then
        changes="- Production build with latest updates and optimizations
- Enhanced stability and performance improvements
- Updated dependencies and security fixes"
    fi
    
    echo
    log_info "Release Configuration:"
    echo "  Version: $version"
    echo "  Title: $title"
    echo "  Repository: $REPO"
    echo "  APK Path: $APK_PATH"
    echo
    
    # Confirm before proceeding
    if [ "$dry_run" = false ]; then
        # Skip confirmation if RELEASE_VERSION is set (automated build)
        if [ -z "$RELEASE_VERSION" ]; then
            read -p "Proceed with release creation? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_warning "Release cancelled by user"
                exit 0
            fi
        else
            log_info "Automated release - skipping confirmation"
        fi
    fi
    
    # Build the release
    build_release
    
    if [ "$dry_run" = true ]; then
        log_success "Dry run completed - APK built but no release created"
        echo "APK Location: $APK_PATH"
        exit 0
    fi
    
    # Generate release notes
    local notes
    notes=$(generate_release_notes "$version" "$changes")
    
    # Create GitHub release
    create_github_release "$version" "$title" "$notes"
    
    log_success "Release deployment completed!"
    echo
    echo "Next steps:"
    echo "1. Verify the release at: https://github.com/$REPO/releases/tag/$version"
    echo "2. Test the APK on a device"
    echo "3. Announce the release if needed"
}

# Run main function with all arguments
main "$@"