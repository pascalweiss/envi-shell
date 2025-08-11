#!/usr/bin/env bash
#
# ENVI APPLICATION INTEGRATIONS
# =============================
# Default tool integrations and app-specific configurations
# Sourced by enviinit during environment initialization
# User config can override these settings in config/.envi_app_integrations

# ============================================================================
# TOOL INTEGRATIONS
# ============================================================================

# Homebrew Integration
# Configure environment based on available Homebrew installation paths
configure_homebrew() {
    # Auto-detect Homebrew installation and load environment
    if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# Node Version Manager (NVM) Integration
configure_nvm() {
    # Load NVM if available - automatic detection
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

# Neovim Configuration
configure_neovim() {
    # Use VIMINIT to load configs directly from envi project
    export VIMINIT="lua dofile('$ENVI_HOME/defaults/default_nvim.lua') if vim.fn.filereadable('$ENVI_HOME/config/.envi_nvim') == 1 then dofile('$ENVI_HOME/config/.envi_nvim') end"
    
    # Set neovim as default editor
    export EDITOR=nvim
    export VISUAL=nvim
    
    # Create vim alias to nvim (most portable approach)
    alias vim='nvim'
    alias vi='nvim'
}


# CLI Completion Integrations
configure_cli_completions() {
    if [ -n "$ZSH" ] && typeset -f compdef >/dev/null 2>&1; then
        # Load Flux CLI completion (requires Oh-My-Zsh completion system)
        if command -v flux >/dev/null 2>&1; then
            . <(flux completion zsh)
        fi
        
        # Load Angular CLI completion (requires Oh-My-Zsh completion system)
        if command -v ng >/dev/null 2>&1; then
            . <(ng completion script)
        fi
    fi
}

# ============================================================================
# INITIALIZATION FUNCTIONS
# ============================================================================

# Initialize all app integrations (called from enviinit)
init_app_integrations() {
    configure_homebrew
    configure_nvm
    configure_neovim
}

# Initialize shell-specific app integrations (called from enviinit after Oh-My-Zsh)
init_shell_app_integrations() {
    if [ -n "$ZSH" ]; then
        configure_cli_completions
    fi
}