#!/usr/bin/env bash
#
# NODE/NVM INITIALIZATION
# =======================
# Node: Always eager (for command availability)
# NVM: Always lazy (for startup performance)

export NVM_DIR="$HOME/.nvm"

# Check if NVM is available before proceeding
if [ ! -d "$NVM_DIR" ] || [ ! -s "$NVM_DIR/nvm.sh" ]; then
    [ "$ENVI_TIMING" = "true" ] && echo "ENVI TIMING:     - node/nvm not available" >&2
    return 0
fi

# EAGER NODE LOADING: Add current Node version to PATH immediately
# This ensures Node commands are available right away

# Determine current node version (from default alias or latest available)
if [ -f "$NVM_DIR/alias/default" ]; then
    NODE_VERSION_ALIAS=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
fi

# Resolve version alias to actual version directory
if [ "$NODE_VERSION_ALIAS" = "node" ] || [ -z "$NODE_VERSION_ALIAS" ]; then
    # Get the latest version available
    NODE_VERSION=$(ls "$NVM_DIR/versions/node" 2>/dev/null | sort -V | tail -1)
else
    NODE_VERSION="$NODE_VERSION_ALIAS"
fi

# Add Node bin directory to PATH for immediate command availability
if [ -n "$NODE_VERSION" ] && [ -d "$NVM_DIR/versions/node/$NODE_VERSION/bin" ]; then
    NODE_BIN_PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin"
    export PATH="$NODE_BIN_PATH:$PATH"
    
    # Set essential Node environment variables
    export NVM_BIN="$NODE_BIN_PATH"
    export NVM_CURRENT="$NODE_VERSION"
    
    [ "$ENVI_TIMING" = "true" ] && echo "ENVI TIMING:     - node eager: $NODE_VERSION" >&2
else
    [ "$ENVI_TIMING" = "true" ] && echo "ENVI TIMING:     - node not found" >&2
fi

# LAZY NVM LOADING: Create nvm function that loads full NVM on first use
# This defers the expensive 4661-line script loading until actually needed
nvm() {
    unset -f nvm
    echo "Loading NVM..." >&2
    \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm "$@"
}