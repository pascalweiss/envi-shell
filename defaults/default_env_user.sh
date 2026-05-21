#!/usr/bin/env bash
#
# ENVI DEFAULT ENVIRONMENT SETTINGS
# =================================
# Default feature controls and PATH extensions - copied to ~/.envi/config/envi_env during setup
# User config overrides these defaults. See CLAUDE.md for loading order details.

# Feature Controls (true/false)

# Core environment features
export ENVI_256_COLORS=true
export ENVI_DEBUG=false
export ENVI_UTF_8=true


# SSH agent auto-start for interactive shells
export SSH_AGENT_ENABLED=true
export SSH_AUTO_ADD_KEY=false

# Tmux session management
export TMUX_ENABLED=false
export TMUX_AUTO_ATTACH=false
export TMUX_SHOW_HELP=false
export TMUX_SPLIT_FOLLOW_PWD=true
export ENVI_TMUX_ONLY=false

# Atuin shell history (Warp-style searchable history popup on Up / Ctrl+R)
export ATUIN_ENABLED=true

# fzf-tab: replaces zsh tab-completion menu with an fzf popup
export FZF_TAB_ENABLED=true

# Oh-My-Zsh configuration
export OHMYZSH_ENABLED=true
export OHMYZSH_THEME_LINKING=true
# fzf-tab must be last so it wraps completion-related widgets registered by earlier plugins.
export OHMYZSH_PLUGINS="git kubectl zsh-autosuggestions fzf-tab"
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
