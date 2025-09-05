#!/bin/bash

# Script to rename executables to remove lib prefix according to naming convention
# "No lib prefix needed for executables" - README.md

cd /Users/wangchengye/Documents/GitHub/termux_AI/app/src/main/jniLibs/arm64-v8a

# Define executables that should NOT have lib prefix (these need renaming)
EXECUTABLES_TO_RENAME=(
    # APT utilities (keep only apt.so, rename the rest)
    "libapt-mark.so:apt-mark.so"
    "libapt-cache.so:apt-cache.so" 
    "libapt-config.so:apt-config.so"
    "libapt-get.so:apt-get.so"
    
    # DPKG utilities
    "libdpkg.so:dpkg.so"
    "libdpkg-buildapi.so:dpkg-buildapi.so"
    "libdpkg-buildtree.so:dpkg-buildtree.so"
    "libdpkg-deb.so:dpkg-deb.so"
    "libdpkg-divert.so:dpkg-divert.so"
    "libdpkg-fsys-usrunmess.so:dpkg-fsys-usrunmess.so"
    "libdpkg-query.so:dpkg-query.so"
    "libdpkg-realpath.so:dpkg-realpath.so" 
    "libdpkg-split.so:dpkg-split.so"
    "libdpkg-trigger.so:dpkg-trigger.so"
    "libstart-stop-daemon.so:start-stop-daemon.so"
    "libupdate-alternatives.so:update-alternatives.so"
    
    # Network utilities
    "libcurl-bin.so:curl.so"
    "libwhich.so:which.so"
    
    # SSH utilities
    "libssh-keyscan.so:ssh-keyscan.so"
    "libsshd.so:sshd.so"
    "libsftp.so:sftp.so"
    "libssh-agent.so:ssh-agent.so"
    "libssh.so:ssh.so"
    "libssh-add.so:ssh-add.so"
    "libssh-keygen.so:ssh-keygen.so"
    "libscp.so:scp.so"
    "libenv.so:env.so"
    
    # Core utilities (single executable, not multicall)
    "libcorepack.so:corepack.so"
    
    # Git utilities  
    "libgit-daemon.so:git-daemon.so"
    "libgit-http-backend.so:git-http-backend.so"
    "libgit-http-fetch.so:git-http-fetch.so"
    "libgit-http-push.so:git-http-push.so"
    "libgit-imap-send.so:git-imap-send.so"
    "libgit-remote-http.so:git-remote-http.so"
    "libgit-sh-i18n--envsubst.so:git-sh-i18n--envsubst.so"
    "libgit-receive-pack.so:git-receive-pack.so"
    
    # Text utilities
    "libless.so:less.so"
    "liblessecho.so:lessecho.so"
    "liblesskey.so:lesskey.so"
    
    # Web terminal
    "libttyd.so:ttyd.so"
    
    # Compression utilities
    "libbzip2recover.so:bzip2recover.so"
    "liblzmainfo.so:lzmainfo.so"
    
    # Terminal utilities
    "libtset.so:tset.so"
    
    # Crypto utilities
    "libdumpsexp.so:dumpsexp.so"
    "libmpicalc.so:mpicalc.so"
    "libhmac256.so:hmac256.so"
    "libgpg-error.so:gpg-error.so"
    "libyat2m.so:yat2m.so"
)

echo "Renaming executables to remove lib prefix..."
echo "=========================================="

for rename_pair in "${EXECUTABLES_TO_RENAME[@]}"; do
    OLD_NAME="${rename_pair%%:*}"
    NEW_NAME="${rename_pair##*:}"
    
    if [[ -f "$OLD_NAME" ]]; then
        echo "Renaming: $OLD_NAME -> $NEW_NAME"
        mv "$OLD_NAME" "$NEW_NAME"
    else
        echo "Warning: $OLD_NAME not found"
    fi
done

echo "Done!"