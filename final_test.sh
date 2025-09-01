#\!/bin/bash
echo "Testing fully fixed Termux AI..."
sleep 3

# Clear screen first
adb shell input text "clear"
adb shell input keyevent 66
sleep 1

# Test apt version
adb shell input text "apt\ --version"
adb shell input keyevent 66
sleep 2

# Test node version
adb shell input text "node\ --version"
adb shell input keyevent 66
sleep 2

# Test npm version  
adb shell input text "npm\ --version"
adb shell input keyevent 66
sleep 2

# Test library linkage by running a simple apt command
adb shell input text "apt\ list\ --installed\ 2>/dev/null\ \|\ head\ -3"
adb shell input keyevent 66
sleep 3

# Test simple Node.js command
adb shell input text "echo\ \'console.log\(\"Node.js\ working\"\)\'\|\ node"
adb shell input keyevent 66
sleep 2

echo "Final test completed\!"
