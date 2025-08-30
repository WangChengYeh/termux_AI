#!/data/data/com.termux/files/usr/bin/sh
set -e

WHEELS_DIR="$PREFIX/share/wheels/mcp-cli"
MCP_VERSION="latest"

echo "Installing MCP extension..."

if [ -d "$WHEELS_DIR" ]; then
    # Ensure pip exists and SSL works
    if ! command -v pip >/dev/null 2>&1; then
        echo "Setting up pip..."
        python -m ensurepip --upgrade
    fi
    
    # Install MCP from offline wheels
    echo "Installing MCP from offline wheels..."
    pip install --no-index --find-links="$WHEELS_DIR" "mcp[cli]==$MCP_VERSION" || {
        echo "Warning: Failed to install MCP from wheels, trying fallback installation"
        pip install --no-index --find-links="$WHEELS_DIR" mcp
    }
fi

# Provide a lightweight wrapper if entrypoint not exposed
if ! command -v mcp >/dev/null 2>&1; then
    echo "Creating MCP wrapper script..."
    cat > "$PREFIX/bin/mcp" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exec python -m mcp "$@"
EOF
    chmod +x "$PREFIX/bin/mcp"
fi

echo "MCP extension installed successfully!"
echo "Usage: mcp --help"