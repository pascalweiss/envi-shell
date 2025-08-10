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

# Powerlevel10k Instant Prompt (must run before Oh-My-Zsh)
configure_powerlevel10k_instant_prompt() {
    if [ "$POWERLEVEL10K_ENABLED" = "true" ] && [ -n "$ZSH" ]; then
        # Enable Powerlevel10k instant prompt - should stay close to the top of shell initialization
        # Initialization code that may require console input must go above this block
        if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
            source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
        fi
    fi
}

# Powerlevel10k Theme Loading (must run after Oh-My-Zsh)
configure_powerlevel10k_theme() {
    if [ "$POWERLEVEL10K_ENABLED" = "true" ] && [ -n "$ZSH" ]; then
        # Load Powerlevel10k theme after Oh-My-Zsh
        if [[ -f /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme ]]; then
            # macOS with Apple Silicon (M1/M2) Homebrew
            source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
        elif [[ -f /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme ]]; then
            # macOS with Intel Homebrew
            source /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme
        elif [[ -f /home/linuxbrew/.linuxbrew/share/powerlevel10k/powerlevel10k.zsh-theme ]]; then
            # Linux with Linuxbrew
            source /home/linuxbrew/.linuxbrew/share/powerlevel10k/powerlevel10k.zsh-theme
        elif [[ -f ${ZSH_CUSTOM:-$ZSH/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme ]]; then
            # Oh My Zsh custom theme installation
            source ${ZSH_CUSTOM:-$ZSH/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme
        fi
    fi
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
}

# Initialize shell-specific app integrations (called from enviinit after Oh-My-Zsh)
init_shell_app_integrations() {
    if [ -n "$ZSH" ]; then
        configure_powerlevel10k_theme
        configure_cli_completions
    fi
}