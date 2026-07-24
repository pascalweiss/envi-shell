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

# --- Agent instructions (executables/bin/envi-agent-notes) ---
# Which envi tools the coding agents on THIS machine are told about. Each tool is
# documented in ~/.envi/agent-instructions/<tool>.md; envi-agent-notes injects a
# routing block for the selected ones into each agent's global config. Re-run
# `envi-agent-notes` after changing this.
# export ENVI_AGENT_TOOLS="all"              # default: all tools (bw-run erun gitscan ...)
# export ENVI_AGENT_TOOLS="erun gitscan"     # e.g. a work machine without the secret broker
# export ENVI_AGENT_TOOLS="none"             # tell agents about no envi tools

# --- gitscan (executables/bin/gitscan) ---
# Finds every git repo on this machine and reports uncommitted / unpushed /
# unpulled work. Defaults are baked into the command; override here per machine.
# export GITSCAN_ROOTS="$HOME/dev $HOME/.envi"   # search roots (default: $HOME)
# export GITSCAN_MAX_DEPTH=8                      # find maxdepth (default: 12)
# export GITSCAN_PRUNE="Downloads Movies"        # EXTRA dir names to skip
# export GITSCAN_JOBS=8                           # parallel inspections (default: #CPUs)

# --- PATH extensions ---
# The envi-shipped PATH baseline (~/.local/bin, /opt/local/bin, pyenv shims, ...)
# is set in enviinit. Prepend your own entries here:
# export PATH="$HOME/dev/tools/bin:$PATH"
