#!/bin/bash
set -e

# Build custom Python-enabled bootstrap for Termux AI
# This script creates a minimal bootstrap with Python support for MCP

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BOOTSTRAP_DIR="$PROJECT_ROOT/app/src/main/assets/bootstrap"
OUTPUT_DIR="$PROJECT_ROOT/build/bootstrap"

echo "Building custom Termux AI bootstrap..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy bootstrap script
cp "$BOOTSTRAP_DIR/bootstrap-python-aarch64.sh" "$OUTPUT_DIR/"

# Make executable
chmod +x "$OUTPUT_DIR/bootstrap-python-aarch64.sh"

# Create checksum
cd "$OUTPUT_DIR"
sha256sum bootstrap-python-aarch64.sh > bootstrap-python-aarch64.sh.sha256

echo "Custom bootstrap built successfully:"
echo "  Location: $OUTPUT_DIR/bootstrap-python-aarch64.sh"
echo "  Checksum: $(cat bootstrap-python-aarch64.sh.sha256)"
echo ""
echo "This bootstrap provides:"
echo "  - Minimal Termux environment"
echo "  - Python 3.11 for aarch64"
echo "  - Pip package manager"
echo "  - MCP extension support"