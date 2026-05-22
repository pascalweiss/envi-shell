#!/usr/bin/env bash
#
# FZF-TAB INITIALIZATION
# ======================
# fzf-tab replaces zsh's default completion menu with an fzf popup.
# Tab triggers it everywhere zsh has completions defined (cd, git, kill,
# ssh, brew, kubectl, ...).
#
# The plugin itself is loaded by Oh-My-Zsh via OHMYZSH_PLUGINS. This file
# only applies zstyle configuration AFTER OMZ has loaded it.
#
# Controlled via FZF_TAB_ENABLED (default: true). No-op when fzf-tab is
# not installed or when running outside zsh.

: "${FZF_TAB_ENABLED:=true}"
export FZF_TAB_ENABLED

if [ "$FZF_TAB_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

# zsh-only; zstyle is a zsh builtin.
if [ -z "$ZSH_VERSION" ]; then
    return 0 2>/dev/null || exit 0
fi

# Skip if fzf-tab is not present (plugin not cloned yet).
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab" ]; then
    return 0 2>/dev/null || exit 0
fi

# Case-insensitive matching and colored entries.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Show category headers so multiple groups are easy to scan.
zstyle ':completion:*:descriptions' format '[%d]'

# fzf-tab does its own menu rendering; disable zsh's built-in menu.
zstyle ':completion:*' menu no

# Switch between completion groups with < and >.
zstyle ':fzf-tab:*' switch-group '<' '>'

# Compact popup, matches the atuin look.
zstyle ':fzf-tab:*' fzf-flags --height=40% --reverse --border

# Folder preview when completing cd targets, using eza if available.
if command -v eza >/dev/null 2>&1; then
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=never $realpath'
elif command -v ls >/dev/null 2>&1; then
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
fi
