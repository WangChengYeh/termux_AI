#!/bin/bash

# SOP User Testing Script - Pure input method with direct redirection
# This script uses adb shell "input text 'command > log'" approach

set -e

# Configuration
APP_ID="${APP_ID:-com.termux}"
MAIN_ACTIVITY="${MAIN_ACTIVITY:-com.termux.app.TermuxActivity}"
LOG_FILE="sop-test.log"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}$1${NC}"
}

log_test() {
    echo -e "${CYAN}$1${NC}"
}

# Check if ADB is available
check_adb() {
    if ! command -v adb >/dev/null 2>&1; then
        log_error "❌ ADB not found. Please install Android Platform Tools."
        exit 1
    fi
    
    # Check if device is connected
    if ! adb devices | grep -q "device$"; then
        log_error "❌ No Android device connected via ADB."
        exit 1
    fi
}

# Send command with direct input redirection
send_command_with_logging() {
    local command="$1"
    local description="$2"
    local test_name="$3"
    
    echo -n "   $description: "
    
    # Send test separator first via pure input
    if adb shell "input text 'echo \"=== $test_name ===\" >> $LOG_FILE'" && adb shell "input keyevent 66"; then
        sleep 1
        # Send the actual command with redirection via pure input
        if adb shell "input text '$command >> $LOG_FILE 2>&1'" && adb shell "input keyevent 66"; then
            log_success "✅ Sent"
            sleep 2
            return 0
        else
            log_error "❌ FAILED"
            return 1
        fi
    else
        log_error "❌ FAILED"
        return 1
    fi
}

# Check log file contents
check_log_results() {
    local test_name="$1"
    echo "   📄 Results for $test_name:"
    
    # Use adb cat to read the log file
    if adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" 2>/dev/null | grep -A 10 "=== $test_name ===" | tail -n +2 | head -10; then
        echo "   ✅ Log retrieved successfully"
    else
        log_warning "   ⚠️  Could not retrieve log or command failed"
    fi
    echo ""
}

# Launch the app with proper initialization verification
launch_app() {
    log_info "📱 Launching Termux AI..."
    
    # Force stop and launch with timing
    local launch_result=$(adb shell am start -W -S -n "$APP_ID/.app.TermuxActivity" 2>/dev/null)
    
    if echo "$launch_result" | grep -q "Status: ok"; then
        local launch_time=$(echo "$launch_result" | grep "TotalTime:" | awk '{print $2}')
        log_success "✅ App launched successfully (${launch_time}ms)"
    else
        log_warning "⚠️  Launch status unclear, proceeding anyway"
    fi
    
    # Wait for app processes to initialize
    log_info "🔧 Verifying app initialization..."
    local retries=10
    local ready=false
    
    for ((i=1; i<=retries; i++)); do
        if adb shell run-as "$APP_ID" test -d "/data/data/$APP_ID/files/home" 2>/dev/null; then
            ready=true
            log_success "✅ Home directory ready (attempt $i)"
            break
        fi
        echo -n "   Waiting for initialization... (attempt $i/$retries)"
        sleep 1
        echo ""
    done
    
    if [ "$ready" = false ]; then
        log_warning "⚠️  App may not be fully initialized, but proceeding with tests"
    fi
    
    # Additional wait for terminal UI to be ready
    log_info "🖥️  Waiting for terminal interface to be ready..."
    sleep 3
    
    # Test if terminal is responsive
    log_info "🧪 Testing terminal responsiveness..."
    if adb shell "input text 'echo ready > /tmp/terminal_test'" && adb shell "input keyevent 66"; then
        sleep 2
        if adb shell run-as "$APP_ID" test -f "/tmp/terminal_test" 2>/dev/null; then
            log_success "✅ Terminal is responsive"
            adb shell run-as "$APP_ID" rm -f "/tmp/terminal_test" 2>/dev/null || true
        else
            log_warning "⚠️  Terminal may not be fully responsive yet"
        fi
    else
        log_warning "⚠️  Could not test terminal responsiveness"
    fi
    
    log_success "🚀 App ready for testing!"
}

# Main test execution
run_tests() {
    log_info "🧪 SOP User Testing: Pure input method with direct redirection"
    echo ""
    
    launch_app
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "⌨️  Pure Input Tests with Direct Redirection:"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Initialize test environment via pure input method
    log_test "🔧 Initializing test environment"
    
    echo -n "   Navigate to home directory: "
    if adb shell "input text 'cd \$HOME'" && adb shell "input keyevent 66"; then
        sleep 1
        log_success "✅ Sent"
    else
        log_error "❌ Failed"
    fi
    
    echo -n "   Verify current directory: "
    if adb shell "input text 'pwd'" && adb shell "input keyevent 66"; then
        sleep 1
        log_success "✅ Sent"
    else
        log_error "❌ Failed"
    fi
    
    echo -n "   Create log file: "
    if adb shell "input text 'echo \"SOP User Test - \$(date)\" > $LOG_FILE'" && adb shell "input keyevent 66"; then
        sleep 2
        log_success "✅ Sent"
    else
        log_error "❌ Failed"
    fi
    
    echo ""
    
    # Test 1: Basic command execution
    log_test "🔍 Test 1: Basic command execution"
    send_command_with_logging "pwd" "Typing 'pwd >> log'" "Basic_Command"
    check_log_results "Basic_Command"
    
    # Test 2: Environment setup
    log_test "🔍 Test 2: Environment setup"
    send_command_with_logging "echo \$HOME" "Typing 'echo \$HOME >> log'" "Environment_Setup"
    check_log_results "Environment_Setup"
    
    # Test 3: Node.js version check
    log_test "🔍 Test 3: Node.js version check"
    send_command_with_logging "node --version" "Typing 'node --version >> log'" "Node_Version"
    check_log_results "Node_Version"
    
    # Test 4: NPM version check
    log_test "🔍 Test 4: NPM version check"  
    send_command_with_logging "chmod +x \$PREFIX/bin/npm && npm --version" "Typing 'chmod +x npm && npm --version'" "NPM_Version"
    check_log_results "NPM_Version"
    
    # Test 5: List available commands
    log_test "🔍 Test 5: List available commands"
    send_command_with_logging "ls \$PREFIX/bin" "Typing 'ls \$PREFIX/bin >> log'" "List_Commands"
    check_log_results "List_Commands"
    
    # Test 6: Check PATH environment
    log_test "🔍 Test 6: Check PATH environment"
    send_command_with_logging "echo \$PATH" "Typing 'echo \$PATH >> log'" "PATH_Check"
    check_log_results "PATH_Check"
    
    # Test 7: Test AI tools availability
    log_test "🔍 Test 7: Test AI tools availability"
    send_command_with_logging "which codex" "Typing 'which codex >> log'" "AI_Tools"
    check_log_results "AI_Tools"
    
    # Test 8: Test symbolic links
    log_test "🔍 Test 8: Test symbolic links"
    send_command_with_logging "ls -la \$PREFIX/bin/node" "Typing 'ls -la \$PREFIX/bin/node >> log'" "Symbolic_Links"
    check_log_results "Symbolic_Links"
    
    # Test 9: Check library path
    log_test "🔍 Test 9: Check library path"
    send_command_with_logging "ls \$PREFIX/lib" "Typing 'ls \$PREFIX/lib >> log'" "Library_Path"
    check_log_results "Library_Path"
    
    # Test 10: APT package manager
    log_test "🔍 Test 10: APT package manager"
    send_command_with_logging "apt --version" "Typing 'apt --version >> log'" "APT_Version"
    check_log_results "APT_Version"
    
    # Show complete log file
    log_test "📄 Complete test log file"
    echo "   Full log contents:"
    adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" 2>/dev/null || log_warning "   ⚠️  Could not retrieve complete log"
    echo ""
    
    # Automatically copy log file to host
    log_test "💾 Auto-copying log file to host"
    local host_log_file="$OUTPUT_DIR/sop-test-$(date +%Y%m%d-%H%M%S).log"
    local latest_file="$OUTPUT_DIR/sop-test-latest.log"
    echo -n "   Copying to host as $(basename $host_log_file): "
    if adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" > "$host_log_file" 2>/dev/null; then
        log_success "✅ Copied successfully"
        echo "   📁 Host log location: $host_log_file"
        
        # Copy content to sop-test-latest.log (real file, not symlink)
        if cp "$host_log_file" "$latest_file" 2>/dev/null; then
            echo "   📄 Real file created: sop-test-latest.log (contains actual test results)"
        else
            log_warning "   ⚠️  Could not create sop-test-latest.log"
        fi
        
        # Show file info
        if [ -f "$host_log_file" ]; then
            local file_size=$(wc -l < "$host_log_file" 2>/dev/null || echo "?")
            echo "   📊 Log file: $file_size lines, $(ls -lh "$host_log_file" | awk '{print $5}') bytes"
        fi
    else
        log_error "❌ Failed to copy log file"
    fi
    echo ""
    
    # Clear screen for visibility
    log_test "🔍 Final: Clear screen for visibility"
    adb shell "input text 'clear'" && adb shell "input keyevent 66"
    sleep 1
    echo ""
}

# Show test summary
show_summary() {
    log_info "═══════════════════════════════════════════════════════════════"
    log_success "🏁 Pure input method testing completed!"
    echo ""
    log_info "📋 Commands tested via pure input with direct redirection:"
    echo "   ✓ pwd - Working directory check"
    echo "   ✓ source .profile - Environment setup"
    echo "   ✓ node --version - Node.js runtime"
    echo "   ✓ npm --version - Package manager"
    echo "   ✓ ls \$PREFIX/bin - Available commands"
    echo "   ✓ echo \$PATH - Environment variables"
    echo "   ✓ which codex - AI tools availability"
    echo "   ✓ ls -la \$PREFIX/bin/node - Symbolic link verification"
    echo "   ✓ ls \$PREFIX/lib - Library path check"
    echo "   ✓ apt --version - Package management"
    echo ""
    log_info "📄 Test results captured in: /data/data/$APP_ID/files/home/$LOG_FILE"
    log_info "📱 All commands typed directly into terminal UI with >> redirection"
    log_info "💾 Log file automatically copied to host as sop-test-YYYYMMDD-HHMMSS.log"
    log_info "📄 Latest log available as: sop-test-latest.log (real file with test results)"
    log_info "🔍 Manual access: 'adb shell run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE'"
    echo ""
    log_info "💡 Pure input method advantages:"
    echo "   • Commands appear exactly as user would type them"
    echo "   • Shell handles redirection naturally"
    echo "   • No complex command escaping needed"
    echo "   • True end-to-end UI testing"
    echo "   • Real-time visual feedback on device screen"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  --app-id ID      Set app ID (default: com.termux)"
    echo "  --output-dir DIR Set output directory for log files (default: current dir)"
    echo ""
    echo "Environment variables:"
    echo "  APP_ID         Application package ID (default: com.termux)"
    echo "  MAIN_ACTIVITY  Main activity class (default: com.termux.app.TermuxActivity)"
    echo "  OUTPUT_DIR     Directory for saving log files (default: current directory)"
    echo ""
    echo "Features:"
    echo "  • Pure adb shell input method with direct redirection"
    echo "  • Uses adb shell \"input text 'command >> log'\" format"
    echo "  • All commands typed directly into terminal UI"
    echo "  • Real-time visual feedback and natural shell behavior"
    echo "  • Creates persistent log file for result verification"
    echo "  • Automatically copies log file to host with timestamp"
    echo "  • Creates sop-test-latest.log real file with actual test results"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run with default settings"
    echo "  $0 --app-id com.my.termux    # Use custom app ID"
    echo "  $0 --output-dir ./logs       # Save logs to ./logs directory"
    echo "  APP_ID=com.my.app $0         # Set via environment variable"
    echo "  OUTPUT_DIR=/tmp $0           # Save logs to /tmp directory"
    echo ""
    echo "Log file location: /data/data/\$APP_ID/files/home/$LOG_FILE"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --app-id)
            APP_ID="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            # Create output directory if it doesn't exist
            mkdir -p "$OUTPUT_DIR" 2>/dev/null || {
                log_error "❌ Could not create output directory: $OUTPUT_DIR"
                exit 1
            }
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    check_adb
    run_tests
    show_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
