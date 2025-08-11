#!/usr/bin/env bash
#
# NODE/NVM INITIALIZATION
# =======================
# Lazy loading Node Version Manager (NVM) integration
# NVM is only loaded when first used to improve shell startup time

# Lazy NVM loading function
nvm() {
    # Remove this function definition
    unset -f nvm
    
    # Load NVM with completions
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Call nvm with the original arguments
    nvm "$@"
}