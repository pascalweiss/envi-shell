#!/usr/bin/env bash
#
# GHOSTTY INITIALIZATION
# ======================
# Ghostty is a macOS-first terminal. Its config lives at
# ~/.config/ghostty/config and is symlinked to the envi-tracked file
# so edits are versioned and shared across machines (same pattern as
# atuin, zsh, tmux, git).
#
# Controlled via GHOSTTY_ENABLED (default: true). No-op on Linux and
# whenever the source config is missing.

if [ "$GHOSTTY_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

# Ghostty is macOS-only at the moment.
if [ "$(uname)" != "Darwin" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -f "$ENVI_HOME/integrations/ghostty/config" ]; then
    link_with_backup "$ENVI_HOME/integrations/ghostty/config" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
fi
