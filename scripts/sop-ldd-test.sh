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
    
    # First check if it's a symlink in /usr/bin using run-as
    local symlink_check=$(adb shell "run-as $APP_ID ls -la /data/data/$APP_ID/files/usr/bin/$exe_name 2>/dev/null" 2>/dev/null | tr -d '\r')
    local exe_path=""
    local exe_exists="NOT_FOUND"
    
    if echo "$symlink_check" | grep -q "\->"; then
        # It's a symlink, extract the target
        local symlink_target=$(echo "$symlink_check" | awk -F' -> ' '{print $2}')
        exe_path="$symlink_target"
        info "Found symlink: /usr/bin/$exe_name -> $symlink_target"
        exe_exists="EXISTS"
    else
        # Check other locations
        # Try to find the actual .so file in app lib directory
        local app_lib_dir=$(adb shell "ls -d /data/app/*/com.termux*/lib/arm64 2>/dev/null | head -n1" 2>/dev/null | tr -d '\r\n')
        if [ -z "$app_lib_dir" ]; then
            app_lib_dir=$(adb shell "ls -d /data/app/*/com.termux*/lib/arm64-v8a 2>/dev/null | head -n1" 2>/dev/null | tr -d '\r\n')
        fi
        
        if [ -n "$app_lib_dir" ]; then
            # Check for the .so file
            local so_check=$(adb shell "ls -la $app_lib_dir/${exe_name}.so 2>/dev/null" 2>/dev/null | tr -d '\r')
            if [ -n "$so_check" ] && ! echo "$so_check" | grep -q "No such file"; then
                exe_path="$app_lib_dir/${exe_name}.so"
                info "Found executable at: $exe_path"
                exe_exists="EXISTS"
            fi
        fi
        
        # If still not found, check system locations
        if [ "$exe_exists" = "NOT_FOUND" ]; then
            local exe_paths=(
                "/system/bin/$exe_name" 
                "/system/xbin/$exe_name"
            )
            
            for path in "${exe_paths[@]}"; do
                local check_result=$(adb shell "[ -f '$path' ] && echo 'EXISTS' || echo 'NOT_FOUND'")
                check_result=$(echo "$check_result" | tr -d '\r\n')
                if [ "$check_result" = "EXISTS" ]; then
                    exe_path="$path"
                    exe_exists="EXISTS"
                    break
                fi
            done
        fi
    fi
    
    if [ "$exe_exists" = "NOT_FOUND" ] || [ -z "$exe_path" ]; then
        error "Executable '$exe_name' not found"
        log "Checked locations:"
        log "  - /data/data/$APP_ID/files/usr/bin/$exe_name (via run-as)"
        if [ -n "$app_lib_dir" ]; then
            log "  - $app_lib_dir/${exe_name}.so"
        fi
        log "  - /system/bin/$exe_name"
        log "  - /system/xbin/$exe_name"
        return 1
    fi
    
    info "Found executable at: $exe_path"
    
    # Run ldd on the executable
    log "📋 Running ldd on $exe_path..."
    log "📝 Sourcing .profile to get proper environment variables (PATH, LD_LIBRARY_PATH)..."
    
    # Source .profile to get proper environment variables
    # Use run-as if the executable is in the app's private directory
    local ldd_output=""
    if echo "$exe_path" | grep -q "/data/data/$APP_ID"; then
        # Source .profile first to get proper PATH and LD_LIBRARY_PATH, then run ldd
        ldd_output=$(adb shell "run-as $APP_ID sh -c 'cd /data/data/$APP_ID/files/home && source .profile 2>/dev/null; ldd \"$exe_path\"' 2>&1 || echo 'LDD_FAILED'")
    else
        # For system executables, still source .profile for consistent environment
        ldd_output=$(adb shell "run-as $APP_ID sh -c 'cd /data/data/$APP_ID/files/home && source .profile 2>/dev/null; ldd \"$exe_path\"' 2>&1 || echo 'LDD_FAILED'")
    fi
    
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
        # Core Termux AI executables
        "ffmpeg"
        "ffprobe"
        "node"
        "git"
        "gh"
        "vim"
        "bash"
        "apt"
        "dpkg"
        # System executables
        "ls"
        "cat" 
        "grep"
        "awk"
        "sed"
        "tar"
        "gzip"
        "unzip"
    )
    
    # Try to get list of available Termux executables if possible
    local termux_executables=$(adb shell "export PATH=/data/data/$APP_ID/files/usr/bin:/system/bin:/system/xbin && ls /data/data/$APP_ID/files/usr/bin 2>/dev/null | head -10" 2>/dev/null || echo "")
    
    if [ -n "$termux_executables" ]; then
        info "Found Termux executables, adding to test list:"
        while IFS= read -r exe; do
            if [ -n "$exe" ]; then
                executables+=("$exe")
                info "  - $exe"
            fi
        done <<< "$termux_executables"
    else
        warn "Could not access Termux executable directory, testing system executables only"
    fi
    
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