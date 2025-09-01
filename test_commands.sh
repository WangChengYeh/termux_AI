#\!/bin/bash
echo "Testing Termux AI with comprehensive libraries..."
sleep 2

# Test basic commands
adb shell input text "ls\ -la\ /data/data/com.termux/files/usr/bin/\ \|\ head"
adb shell input keyevent 66
sleep 2

# Test apt
adb shell input text "apt\ --version"
adb shell input keyevent 66
sleep 2

# Test node
adb shell input text "node\ --version"
adb shell input keyevent 66
sleep 2

# Test npm
adb shell input text "npm\ --version"
adb shell input keyevent 66
sleep 2

# Test library paths
adb shell input text "ls\ /data/app/*/lib/arm64/\ \|\ wc\ -l"
adb shell input keyevent 66
sleep 2

echo "Tests sent to device. Please check the Termux screen for results."
