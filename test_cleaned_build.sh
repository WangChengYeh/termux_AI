#!/bin/bash

echo "Testing cleaned APK build..."

# Launch Termux
echo "Launching Termux app..."
adb shell am start -n com.termux/.app.TermuxActivity

echo "Waiting for app to start..."
sleep 5

# Send APT test command
echo "Testing APT..."
adb shell input text "apt --version"
sleep 1
adb shell input keyevent 66  # Enter
sleep 3

# Clear and test Node.js
echo "Testing Node.js..."
adb shell input keyevent 67  # Backspace to clear
sleep 1
adb shell input text "clear && node --version"
sleep 1
adb shell input keyevent 66  # Enter
sleep 3

# Test npm
echo "Testing npm..."
adb shell input text "npm --version"
sleep 1
adb shell input keyevent 66  # Enter
sleep 3

echo "Testing complete. Please check the Termux terminal on your device for results."
echo "Both APT and Node.js should display their version numbers if working correctly."