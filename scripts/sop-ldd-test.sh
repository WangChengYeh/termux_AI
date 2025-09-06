#!/bin/bash

# SOP Library Dependency Testing Script
# Tests executables using ldd to check for missing libraries
# Usage: ./scripts/sop-ldd-test.sh [EXECUTABLE_NAME]

set -e

APP_ID="${APP_ID:-com.termux}"
MAIN_ACTIVITY="${MAIN_ACTIVITY:-com.termux.app.TermuxActivity}"
TEST_LOG="sop-ldd-test-$(date +%Y%m%d-%H%M%S).log"
MISSING_LIBS_LOG="missing-libs-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "$1" | tee -a "$TEST_LOG"
}

error() {
    echo -e "${RED}❌ ERROR: $1${NC}" | tee -a "$TEST_LOG"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$TEST_LOG"
}

warn() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}" | tee -a "$TEST_LOG"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$TEST_LOG"
}

# Check if device is connected
check_device() {
    if ! adb devices | grep -q "device$"; then
        error "No Android device connected via ADB"
        exit 1
    fi
}

# Check if Termux AI app is installed
check_app() {
    if ! adb shell pm list packages | grep -q "$APP_ID"; then
        error "Termux AI app ($APP_ID) is not installed"
        exit 1
    fi
}

# Start Termux AI app if not running
start_app() {
    log "🚀 Starting Termux AI app..."
    adb shell am start -n "$APP_ID/$MAIN_ACTIVITY" >/dev/null 2>&1
    sleep 3
}

# Test executable with ldd
test_executable() {
    local exe_name="$1"
    
    log "🔍 Testing executable: $exe_name"
    
    # Get the full path of the executable
    # Check common locations for executables in Termux AI
    local exe_paths=(
        "/data/data/$APP_ID/files/usr/bin/$exe_name"
        "/system/bin/$exe_name" 
        "/system/xbin/$exe_name"
    )
    
    local exe_path=""
    local exe_exists="NOT_FOUND"
    
    for path in "${exe_paths[@]}"; do
        local check_result=$(adb shell "[ -f '$path' ] && echo 'EXISTS' || echo 'NOT_FOUND'")
        check_result=$(echo "$check_result" | tr -d '\r\n')
        if [ "$check_result" = "EXISTS" ]; then
            exe_path="$path"
            exe_exists="EXISTS"
            break
        fi
    done
    
    if [ "$exe_exists" = "NOT_FOUND" ] || [ -z "$exe_path" ]; then
        error "Executable '$exe_name' not found in any of the checked locations"
        return 1
    fi
    
    info "Found executable at: $exe_path"
    
    # Run ldd on the executable
    log "📋 Running ldd on $exe_path..."
    local ldd_output=$(adb shell "export LD_LIBRARY_PATH=/data/data/$APP_ID/files/usr/lib:/system/lib64:/system/lib && ldd '$exe_path' 2>&1 || echo 'LDD_FAILED'")
    
    if echo "$ldd_output" | grep -q "LDD_FAILED"; then
        error "ldd failed to analyze $exe_path"
        log "Output: $ldd_output"
        return 1
    fi
    
    # Check for "not found" libraries
    local missing_libs=$(echo "$ldd_output" | grep "not found" || true)
    
    if [ -n "$missing_libs" ]; then
        error "Missing libraries found for $exe_name:"
        echo "$missing_libs" | while read -r line; do
            local lib_name=$(echo "$line" | awk '{print $1}')
            error "  - $lib_name"
            echo "$exe_name: $lib_name" >> "$MISSING_LIBS_LOG"
        done
        log "Full ldd output:"
        log "$ldd_output"
        return 1
    else
        success "All libraries found for $exe_name"
        log "Full ldd output:"
        log "$ldd_output"
        return 0
    fi
}

# Test all common executables
test_all_executables() {
    local executables=(
        "ffmpeg"
        "ffprobe" 
        "node"
        "npm"
        "git"
        "bash"
        "ls"
        "cat"
        "grep"
        "awk"
        "sed"
        "curl"
        "wget"
        "tar"
        "gzip"
        "unzip"
        "python"
        "pip"
        "gcc"
        "make"
        "cmake"
        "pkg-config"
        "freetype-config"
        "gemini"
        "claude"
        "codex"
    )
    
    local failed_count=0
    local total_count=${#executables[@]}
    
    log "🧪 Testing ${total_count} executables for missing libraries..."
    log "============================================================"
    
    for exe in "${executables[@]}"; do
        log ""
        if ! test_executable "$exe"; then
            ((failed_count++))
        fi
        sleep 1
    done
    
    log ""
    log "============================================================"
    log "📊 Test Summary:"
    log "  Total executables tested: $total_count"
    log "  Successful: $((total_count - failed_count))"
    log "  Failed: $failed_count"
    
    if [ $failed_count -gt 0 ]; then
        error "Some executables have missing library dependencies"
        log "Missing libraries summary saved to: $MISSING_LIBS_LOG"
        log ""
        log "To resolve missing libraries, use the SOP workflow:"
        log "  1. Find the package containing the missing library:"
        log "     make sop-find-lib LIBRARY=<missing-lib-name>"
        log "  2. Add the package:"
        log "     make sop-add-package PACKAGE_NAME=<package-name> VERSION=<version>"
        log "  3. Re-test:"
        log "     make sop-ldd-test"
        return 1
    else
        success "All tested executables have their library dependencies satisfied!"
        return 0
    fi
}

# Test specific executable or all
test_specific_or_all() {
    if [ -n "$1" ]; then
        log "🎯 Testing specific executable: $1"
        test_executable "$1"
    else
        test_all_executables
    fi
}

main() {
    log "🔧 SOP Library Dependency Testing"
    log "================================="
    log "Date: $(date)"
    log "Device: $(adb shell getprop ro.product.model 2>/dev/null || echo 'Unknown')"
    log "App ID: $APP_ID"
    log "Log file: $TEST_LOG"
    log ""
    
    check_device
    check_app
    start_app
    
    # Wait for app to initialize
    sleep 5
    
    test_specific_or_all "$1"
    
    local exit_code=$?
    
    log ""
    log "🏁 Testing completed at $(date)"
    log "Full log saved to: $TEST_LOG"
    
    if [ $exit_code -eq 0 ]; then
        success "All library dependencies satisfied!"
    else
        error "Some executables have missing dependencies"
        if [ -f "$MISSING_LIBS_LOG" ]; then
            log "Missing libraries list: $MISSING_LIBS_LOG"
        fi
    fi
    
    exit $exit_code
}

# Handle script arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "SOP Library Dependency Testing Script"
    echo ""
    echo "Usage:"
    echo "  $0                    # Test all common executables"
    echo "  $0 EXECUTABLE_NAME    # Test specific executable"
    echo "  $0 --help            # Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test ffmpeg, node, git, etc."
    echo "  $0 ffmpeg            # Test only ffmpeg"
    echo "  $0 python           # Test only python"
    echo ""
    echo "Environment variables:"
    echo "  APP_ID              # Termux AI app package ID (default: com.termux)"
    echo "  MAIN_ACTIVITY       # Main activity class (default: com.termux.app.TermuxActivity)"
    exit 0
fi

main "$1"