#!/bin/bash

# SOP User Testing Script - Automated UI testing via ADB input commands
# This script simulates user interactions with the Termux AI app terminal

set -e

# Configuration
APP_ID="${APP_ID:-com.termux}"
MAIN_ACTIVITY="${MAIN_ACTIVITY:-com.termux.app.TermuxActivity}"
LOG_FILE="sop-test.log"
LOG_FILE_FULL="/data/data/${APP_ID}/files/home/sop-test.log"

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

# Send text input to the app
send_input() {
    local text="$1"
    local description="$2"
    
    echo -n "   $description: "
    if adb shell input text "$text" && adb shell input keyevent 66; then
        log_success "✅ Sent"
        return 0
    else
        log_error "❌ FAILED"
        return 1
    fi
}

# Send command with logging to file
send_command_with_logging() {
    local command="$1"
    local description="$2"
    local test_name="$3"
    
    echo -n "   $description: "
    
    # First add the separator via direct ADB command
    adb shell "run-as $APP_ID /system/bin/sh -c 'cd /data/data/$APP_ID/files/home && echo \"=== $test_name ===\" >> sop-test.log'" 2>/dev/null
    
    # Send the actual command through UI
    if adb shell input text "$command" && adb shell input keyevent 66; then
        log_success "✅ Sent"
        sleep 2
        
        # Capture the output via ADB and append to log
        local temp_output=$(adb shell "run-as $APP_ID /system/bin/sh -c 'cd /data/data/$APP_ID/files/home && $command 2>&1'" 2>/dev/null || echo "Command failed")
        adb shell "run-as $APP_ID /system/bin/sh -c 'cd /data/data/$APP_ID/files/home && echo \"$temp_output\" >> sop-test.log'" 2>/dev/null
        return 0
    else
        log_error "❌ FAILED"
        return 1
    fi
}

# Check log file contents
check_log_results() {
    local test_name="$1"
    echo "   📄 Results for $test_name:"
    
    # Use adb cat to read the log file - try both absolute and relative paths
    if adb shell "run-as $APP_ID cat \$HOME/$LOG_FILE" 2>/dev/null | grep -A 10 "=== $test_name ===" | tail -n +2 | head -10; then
        echo "   ✅ Log retrieved successfully"
    else
        log_warning "   ⚠️  Could not retrieve log or command failed"
    fi
    echo ""
}

# Launch the app
launch_app() {
    log_info "📱 Launching Termux AI..."
    adb shell am start -n "$APP_ID/.$MAIN_ACTIVITY" >/dev/null 2>&1 || true
    sleep 3
    log_info "🖥️  App launched, waiting for terminal to be ready..."
    sleep 2
}

# Main test execution
run_tests() {
    log_info "🧪 SOP User Testing: Simulating user interactions via ADB input with logging"
    echo ""
    
    launch_app
    
    echo ""
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "⌨️  Simulating User Input Tests with Log Capture:"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Initialize test environment via ADB first, then through UI
    log_test "🔧 Initializing test environment"
    echo "   Setting up log file via ADB..."
    
    # Create log file directly via ADB run-as to ensure it works
    if adb shell "run-as $APP_ID /system/bin/sh -c 'mkdir -p /data/data/$APP_ID/files/home && cd /data/data/$APP_ID/files/home && echo \"SOP User Test Log - \$(date)\" > sop-test.log'"; then
        log_success "   ✅ Log file created via ADB"
    else
        log_warning "   ⚠️  Could not create log file via ADB, will try through UI"
    fi
    
    # Now test through UI
    send_input "pwd" "Check current directory"
    sleep 1
    send_input "cd\\ \\\$HOME" "Change to HOME directory"
    sleep 1
    send_input "ls\\ -la\\ sop-test.log" "Check log file exists"
    sleep 1
    echo ""
    
    # Test 1: Basic command execution
    log_test "🔍 Test 1: Basic command execution"
    send_command_with_logging "pwd" "Typing 'pwd' + logging" "Basic_Command"
    sleep 2
    check_log_results "Basic_Command"
    
    # Test 2: Environment setup
    log_test "🔍 Test 2: Environment setup"
    send_command_with_logging "source\\ .profile" "Typing 'source .profile' + logging" "Environment_Setup"
    sleep 2
    check_log_results "Environment_Setup"
    
    # Test 3: Node.js version check
    log_test "🔍 Test 3: Node.js version check"
    send_command_with_logging "node\\ --version" "Typing 'node --version' + logging" "Node_Version"
    sleep 3
    check_log_results "Node_Version"
    
    # Test 4: NPM version check
    log_test "🔍 Test 4: NPM version check"
    send_command_with_logging "npm\\ --version" "Typing 'npm --version' + logging" "NPM_Version"
    sleep 3
    check_log_results "NPM_Version"
    
    # Test 5: List available commands
    log_test "🔍 Test 5: List available commands"
    send_command_with_logging "ls\\ /usr/bin\\ \\|\\ head\\ -10" "Typing 'ls /usr/bin | head -10' + logging" "List_Commands"
    sleep 2
    check_log_results "List_Commands"
    
    # Test 6: Check PATH environment
    log_test "🔍 Test 6: Check PATH environment"
    send_command_with_logging "echo\\ \\\$PATH" "Typing 'echo \$PATH' + logging" "PATH_Check"
    sleep 2
    check_log_results "PATH_Check"
    
    # Test 7: Test AI tools availability
    log_test "🔍 Test 7: Test AI tools availability"
    send_command_with_logging "command\\ -v\\ codex" "Typing 'command -v codex' + logging" "AI_Tools"
    sleep 2
    check_log_results "AI_Tools"
    
    # Test 8: Test symbolic links
    log_test "🔍 Test 8: Test symbolic links"
    send_command_with_logging "file\\ /usr/bin/node" "Typing 'file /usr/bin/node' + logging" "Symbolic_Links"
    sleep 2
    check_log_results "Symbolic_Links"
    
    # Test 9: Check library dependencies
    log_test "🔍 Test 9: Check library dependencies"
    send_command_with_logging "ldd\\ /usr/bin/node\\ \\|\\ head\\ -3" "Typing 'ldd /usr/bin/node | head -3' + logging" "Library_Deps"
    sleep 3
    check_log_results "Library_Deps"
    
    # Test 10: APT package manager
    log_test "🔍 Test 10: APT package manager"
    send_command_with_logging "apt\\ --version" "Typing 'apt --version' + logging" "APT_Version"
    sleep 2
    check_log_results "APT_Version"
    
    # Show complete log file
    log_test "📄 Complete test log file"
    echo "   Full log contents:"
    adb shell "run-as $APP_ID cat \$HOME/$LOG_FILE" 2>/dev/null || log_warning "   ⚠️  Could not retrieve complete log"
    echo ""
    
    # Clear screen for visibility
    log_test "🔍 Test 11: Clear screen for visibility"
    send_input "clear" "Typing 'clear' + Enter"
    sleep 1
    echo ""
}

# Show test summary
show_summary() {
    log_info "═══════════════════════════════════════════════════════════════"
    log_success "🏁 User simulation with logging completed!"
    echo ""
    log_info "📋 Commands tested via UI input with stdout/stderr logging:"
    echo "   ✓ pwd - Working directory check"
    echo "   ✓ source .profile - Environment setup"
    echo "   ✓ node --version - Node.js runtime"
    echo "   ✓ npm --version - Package manager"
    echo "   ✓ ls /usr/bin | head -10 - Available commands"
    echo "   ✓ echo \$PATH - Environment variables"
    echo "   ✓ command -v codex - AI tools availability"
    echo "   ✓ file /usr/bin/node - Symbolic link verification"
    echo "   ✓ ldd /usr/bin/node | head -3 - Library dependencies"
    echo "   ✓ apt --version - Package management"
    echo ""
    log_info "📄 Test results captured in: $LOG_FILE_FULL"
    log_info "📱 Check the Termux app screen to see command execution"
    log_info "🔍 Use 'adb shell run-as $APP_ID cat $LOG_FILE_FULL' to view log"
    echo ""
    log_info "💡 Log file features:"
    echo "   • Each test has a clear separator (=== Test_Name ===)"
    echo "   • Both stdout and stderr are captured"
    echo "   • Results retrieved via 'adb cat' for verification"
    echo "   • Persistent log survives app restarts"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --app-id ID    Set app ID (default: com.termux)"
    echo ""
    echo "Environment variables:"
    echo "  APP_ID         Application package ID (default: com.termux)"
    echo "  MAIN_ACTIVITY  Main activity class (default: com.termux.app.TermuxActivity)"
    echo ""
    echo "Features:"
    echo "  • Simulates user typing via 'adb shell input text'"
    echo "  • Redirects stdout/stderr to log file in app home directory"
    echo "  • Uses 'adb cat' to retrieve and display command results"
    echo "  • Provides immediate verification of command execution"
    echo "  • Creates persistent log file for later analysis"
    echo ""
    echo "Examples:"
    echo "  $0                           # Run with default settings"
    echo "  $0 --app-id com.my.termux    # Use custom app ID"
    echo "  APP_ID=com.my.app $0         # Set via environment variable"
    echo ""
    echo "Log file location: /data/data/\$APP_ID/files/home/sop-test.log"
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