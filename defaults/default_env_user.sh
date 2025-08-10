#!/usr/bin/env bash
#
# ENVI DEFAULT ENVIRONMENT SETTINGS
# =================================
# Default feature controls and PATH extensions - copied to ~/.envi/config/.envi_env during setup
# User config overrides these defaults. See CLAUDE.md for loading order details.

# Feature Controls (true/false)

# Core environment features
export ENVI_256_COLORS=true
export ENVI_DEBUG=false
export ENVI_UTF_8=true

# SSH agent auto-start for interactive shells
export SSH_AGENT_ENABLED=true

# Tmux session management
export TMUX_ENABLED=false
export TMUX_AUTO_ATTACH=false
export TMUX_SHOW_HELP=false

# Oh-My-Zsh configuration
export OHMYZSH_ENABLED=true
export OHMYZSH_THEME_LINKING=true
export OHMYZSH_PLUGINS="git kubectl zsh-autosuggestions"
export OHMYZSH_GIT_PROMPT_CACHE=true
export ZSH_THEME="envi-minimal"  # Minimal theme for tmux integration

# PATH Extensions

export PATH="$HOME/.local/bin:\
/opt/local/bin:\
/opt/local/sbin:\
$HOME/.pyenv/shims:\
/usr/games:\
$HOME/.vimpkg/bin:\
$PATH"
