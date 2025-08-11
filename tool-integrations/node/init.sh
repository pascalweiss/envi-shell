#!/usr/bin/env bash
#
# NODE/NVM INITIALIZATION
# =======================
# Lazy loading Node Version Manager (NVM) integration
# NVM is only loaded when first used to improve shell startup time

# Load NVM immediately to ensure global npm packages are available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"