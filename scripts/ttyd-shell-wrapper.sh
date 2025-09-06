#!/system/bin/sh
# ttyd shell wrapper to bypass SELinux restrictions
# This script runs within Termux environment instead of system shell

export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export HOME="/data/data/com.termux/files/home"
export PREFIX="/data/data/com.termux/files/usr"
export TERMUX_APP_PID=$$
export TMPDIR="/data/data/com.termux/files/usr/tmp"

# Use Termux's bash instead of system shell
exec "/data/data/com.termux/files/usr/bin/bash" "$@"