#!/bin/bash

# Minimal test to identify problematic commands
set -e

APP_ID="${APP_ID:-com.termux}"
LOG_FILE="minimal-test.log"

echo "🧪 Minimal Command Testing"

# Ensure the directory exists via adb first
echo "🔧 Setup: Ensuring home directory exists via adb..."
adb shell "run-as $APP_ID /system/bin/sh -c 'mkdir -p /data/data/$APP_ID/files/home'"

# Launch app  
echo "📱 Launching Termux AI..."
adb shell am start -n "$APP_ID/.app.TermuxActivity" >/dev/null 2>&1 || true
sleep 3

echo "⌨️  Testing individual commands..."

# First ensure we're in the right directory
echo "0. Navigate to home directory"
adb shell input text "cd /data/data/$APP_ID/files/home"
adb shell input keyevent 66
sleep 2

# Test 1: Basic directory commands
echo "1. Testing pwd"
adb shell input text "echo '=== TEST 1: pwd ===' > $LOG_FILE"
adb shell input keyevent 66
sleep 1
adb shell input text "pwd >> $LOG_FILE"
adb shell input keyevent 66
sleep 2

# Check result
echo "   Result:"
adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" 2>/dev/null || echo "   ❌ Failed to retrieve log"
echo ""

# Test 2: Environment variables 
echo "2. Testing environment variables"
adb shell input text "echo '=== TEST 2: HOME ===' >> $LOG_FILE"
adb shell input keyevent 66
sleep 1
adb shell input text "echo \$HOME >> $LOG_FILE"
adb shell input keyevent 66
sleep 2

# Check result
echo "   Result:"
adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" 2>/dev/null || echo "   ❌ Failed to retrieve log"
echo ""

# Test 3: Node.js version
echo "3. Testing Node.js"
adb shell input text "echo '=== TEST 3: Node.js ===' >> $LOG_FILE"
adb shell input keyevent 66
sleep 1
adb shell input text "node --version >> $LOG_FILE"
adb shell input keyevent 66
sleep 3

# Check result
echo "   Result:"
adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" 2>/dev/null || echo "   ❌ Failed to retrieve log"
echo ""

# Test 4: List commands (simple)
echo "4. Testing ls command"
adb shell input text "echo '=== TEST 4: ls bin ===' >> $LOG_FILE"
adb shell input keyevent 66
sleep 1
adb shell input text "ls \$PREFIX/bin >> $LOG_FILE 2>&1"
adb shell input keyevent 66
sleep 3

# Final check
echo "   Final result:"
adb shell "run-as $APP_ID cat /data/data/$APP_ID/files/home/$LOG_FILE" 2>/dev/null || echo "   ❌ Failed to retrieve log"

echo ""
echo "🏁 Minimal test completed"