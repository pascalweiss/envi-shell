#!/usr/bin/env bash
#
# ENVI PER-MACHINE ENVIRONMENT OVERRIDES
# ======================================
# Seeded into ~/.envi/config/envi_env on first install (only if missing).
#
# All envi defaults now live next to their consumers (each integration's
# init.sh, or enviinit for envi-wide settings). This file is purely for
# per-machine overrides — set a variable here to deviate from the envi
# default on THIS machine only.
#
# Loading order (see CLAUDE.md): defaults → this file → integrations.
# Integrations use `: "${VAR:=default}"` so anything you set here wins.
#
# Common overrides — uncomment and edit as needed:

# --- Envi core (enviinit) ---
# export ENVI_256_COLORS=false              # disable 256-color terminal
# export ENVI_UTF_8=false                   # disable LC_ALL=en_US.UTF-8
# export ENVI_TMUX_ONLY=true                # minimal init outside tmux; fast shells

# --- SSH (integrations/ssh) ---
# export SSH_AGENT_ENABLED=false            # disable ssh-agent auto-start

# --- Tmux (integrations/tmux + enviinit) ---
# export TMUX_ENABLED=true                  # auto-start tmux on shell login
# export TMUX_AUTO_ATTACH=true              # attach to existing session on login
# export TMUX_SHOW_HELP=true                # send tmux-help command on attach
# export TMUX_SPLIT_FOLLOW_PWD=false        # rebind splits to not follow cwd

# --- Oh-My-Zsh (integrations/zsh) ---
# export OHMYZSH_ENABLED=false              # disable OMZ entirely
# export OHMYZSH_PLUGINS="git fzf-tab"      # override the default plugin list
# export ZSH_THEME=robbyrussell             # pick a different OMZ theme
# export OHMYZSH_GIT_PROMPT_CACHE=false     # disable git prompt cache
# export OHMYZSH_THEME_LINKING=false        # disable envi custom-theme symlinking

# --- Tool toggles (default: all enabled) ---
# export ATUIN_ENABLED=false
# export FZF_TAB_ENABLED=false
# export ZOXIDE_ENABLED=false
# export BAT_ENABLED=false                  # bat as MANPAGER
# export EZA_ENABLED=false                  # ls/ll/la/lt aliases via eza
# export GHOSTTY_ENABLED=false              # symlink ghostty config from envi

# --- PATH extensions (envi-shipped baseline; appended on every shell) ---
export PATH="$HOME/.local/bin:\
/opt/local/bin:\
/opt/local/sbin:\
$HOME/.pyenv/shims:\
/usr/games:\
$HOME/.vimpkg/bin:\
$PATH"
