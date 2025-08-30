#!/data/data/com.termux/files/usr/bin/sh
set -e

echo "Setting up Codex CLI..."

# Verify Codex installation
if command -v codex >/dev/null 2>&1; then
    echo "Codex CLI is available at: $(which codex)"
    echo "Version: $(codex --version 2>/dev/null || echo 'Unable to get version')"
else
    echo "Warning: Codex CLI not found in PATH"
    echo "Expected location: $PREFIX/bin/codex"
fi

# Set up Codex configuration directory
CODEX_CONFIG_DIR="$HOME/.config/codex"
mkdir -p "$CODEX_CONFIG_DIR"

# Create basic configuration if not exists
if [ ! -f "$CODEX_CONFIG_DIR/config.json" ]; then
    cat > "$CODEX_CONFIG_DIR/config.json" <<'EOF'
{
  "api": {
    "base_url": "https://api.openai.com/v1",
    "timeout": 30
  },
  "models": {
    "default": "gpt-4",
    "fallback": "gpt-3.5-turbo"
  },
  "termux": {
    "ai_ready": true,
    "architecture": "aarch64"
  }
}
EOF
    echo "Created default Codex configuration at $CODEX_CONFIG_DIR/config.json"
fi

echo "Codex CLI setup completed!"
echo "Usage: codex --help"