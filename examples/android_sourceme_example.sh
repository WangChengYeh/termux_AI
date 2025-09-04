#!/system/bin/sh

# Example android_sourceme file
# This file should be placed at /data/local/tmp/android_sourceme
# It will be automatically sourced by Termux AI's .profile on startup

# Custom environment variables
export ANDROID_CUSTOM_VAR="Hello from Android system!"
export DEVELOPMENT_MODE="true"

# Custom aliases
alias ll='ls -la'
alias grep='grep --color=auto'

# Custom functions
termux_info() {
    echo "=== Termux AI Environment ==="
    echo "Node.js: $(node --version 2>/dev/null || echo 'Not available')"
    echo "Git: $(git --version 2>/dev/null || echo 'Not available')"
    echo "GitHub CLI: $(gh --version 2>/dev/null | head -1 || echo 'Not available')"
    echo "PWD: $(pwd)"
    echo "USER: $(whoami)"
    echo "============================="
}

# Set custom PATH additions
export PATH="/system/xbin:/system/bin:$PATH"

# Custom prompt (if supported)
export PS1="[Termux AI] \u@\h:\w\$ "

# Development shortcuts
export EDITOR="vim"
export BROWSER="am start -a android.intent.action.VIEW -d"

# Conditional setup based on environment
if [ "$DEVELOPMENT_MODE" = "true" ]; then
    echo "🚀 Development mode enabled"
    # Enable verbose logging for development
    export DEBUG=1
fi

echo "✅ android_sourceme loaded successfully"