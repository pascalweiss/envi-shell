#!/usr/bin/env bash
#
# ENVI DEFAULT ENVIRONMENT SETTINGS
# =================================
# Default feature controls and PATH extensions - copied to ~/.envi/config/.envi_env during setup
# User config overrides these defaults. See CLAUDE.md for loading order details.

# Feature Controls (true/false)

# SSH agent auto-start for interactive shells
export SSH_AGENT_ENABLED=true

# Powerlevel10k theme loading (zsh only)
export POWERLEVEL10K_ENABLED=true

# Tmux session management
export TMUX_ENABLED=false
export TMUX_AUTO_ATTACH=false
export TMUX_SHOW_HELP=false

# Oh-My-Zsh custom theme linking from dotfiles submodule
export ZSH_THEME_LINKING_ENABLED=true

# PATH Extensions

export PATH="$HOME/.local/bin:\
/usr/local/mysql/bin:\
/opt/local/bin:\
/opt/local/sbin:\
/usr/local/Cellar/pyenv-virtualenv/1.1.1/shims:\
$HOME/.pyenv/shims:\
/Library/TeX/texbin:\
/usr/local/MacGPG2/bin:\
/usr/games:\
$HOME/.vimpkg/bin:\
$PATH"