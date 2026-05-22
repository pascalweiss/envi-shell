#!/usr/bin/env bash
#
# ALACRITTY INITIALIZATION
# ========================
# Cross-platform terminal. Its config lives at ~/.config/alacritty/alacritty.toml
# and is symlinked to the envi-tracked file so edits sync across machines
# (same pattern as ghostty, atuin, tmux, zsh, git).
#
# Controlled via ALACRITTY_ENABLED (default: true). The symlink is only
# created if envi actually ships a tracked alacritty.toml — otherwise
# this init is a no-op so a user's pre-existing local config is preserved.
#
# Seeding the tracked config (do this once, on the machine that already
# has the config you want as the canonical one):
#
#   cp ~/.config/alacritty/alacritty.toml \
#      ~/.envi/integrations/alacritty/alacritty.toml
#   cd ~/.envi && git add integrations/alacritty/alacritty.toml && \
#                 git commit -m "feat(alacritty): seed initial config" && \
#                 git push
#
# On other machines, the next `git pull && exec zsh` will back up the
# local config to ~/dotfiles_backup/ and replace it with the symlink.

: "${ALACRITTY_ENABLED:=true}"
export ALACRITTY_ENABLED

if [ "$ALACRITTY_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -f "$ENVI_HOME/integrations/alacritty/alacritty.toml" ]; then
    link_with_backup "$ENVI_HOME/integrations/alacritty/alacritty.toml" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
fi
