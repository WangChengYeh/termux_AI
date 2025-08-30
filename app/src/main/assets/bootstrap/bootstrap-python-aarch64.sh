#!/data/data/com.termux/files/usr/bin/sh
set -e

# Termux AI Custom Bootstrap with Python Support
# This script creates a minimal Termux environment with Python for MCP extension

BOOTSTRAP_VERSION="2024.12.01"
ARCH="aarch64"
PREFIX="/data/data/com.termux/files/usr"

echo "Installing Termux AI bootstrap (${BOOTSTRAP_VERSION}) for ${ARCH}..."

# Create essential directories
mkdir -p "$PREFIX/bin"
mkdir -p "$PREFIX/lib"
mkdir -p "$PREFIX/share"
mkdir -p "$PREFIX/etc"
mkdir -p "$PREFIX/var/lib/dpkg"
mkdir -p "$PREFIX/tmp"

# Set up minimal environment
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib"
export TMPDIR="$PREFIX/tmp"

# Download and install minimal Python for aarch64
PYTHON_PKG_URL="https://packages.termux.dev/apt/termux-main/pool/main/p/python/python_3.11.6-1_aarch64.deb"
PYTHON_PKG="/tmp/python.deb"

# Use busybox wget if available, otherwise curl
if command -v wget >/dev/null 2>&1; then
    wget -O "$PYTHON_PKG" "$PYTHON_PKG_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$PYTHON_PKG" "$PYTHON_PKG_URL"
else
    echo "Error: Neither wget nor curl available for downloading Python package"
    exit 1
fi

# Extract Python package
cd "$PREFIX"
if command -v ar >/dev/null 2>&1; then
    ar x "$PYTHON_PKG" data.tar.xz
    tar xf data.tar.xz
    rm -f data.tar.xz
else
    echo "Warning: ar not available, using dpkg-deb fallback"
    dpkg-deb -x "$PYTHON_PKG" "$PREFIX" 2>/dev/null || {
        echo "Error: Failed to extract Python package"
        exit 1
    }
fi

# Clean up
rm -f "$PYTHON_PKG"

# Verify Python installation
if [ -x "$PREFIX/bin/python3" ]; then
    echo "Python 3 installed successfully"
    ln -sf python3 "$PREFIX/bin/python"
else
    echo "Warning: Python installation may be incomplete"
fi

# Install minimal pip
if ! command -v pip >/dev/null 2>&1; then
    python -m ensurepip --upgrade 2>/dev/null || {
        echo "Warning: ensurepip failed, pip may not be available"
    }
fi

# Create basic shell environment
cat > "$PREFIX/etc/bash.bashrc" <<'EOF'
export PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib"
export TMPDIR="$PREFIX/tmp"
export PYTHONPATH="$PREFIX/lib/python3.11/site-packages"

# Termux AI specific
export TERMUX_AI_READY=1
export TERMUX_ARCH="aarch64"
EOF

echo "Termux AI bootstrap installation completed!"
echo "Python version: $(python --version 2>/dev/null || echo 'Not available')"
echo "Architecture: $(uname -m)"