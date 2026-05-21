#!/usr/bin/env bash
#
# ATUIN INITIALIZATION
# ====================
# Atuin replaces the shell history with a searchable SQLite-backed store.
# Up-arrow and Ctrl+R open an interactive TUI (Warp-style popup) to browse,
# filter, and pick previous commands.
#
# Controlled via ATUIN_ENABLED (default: true). Requires zsh + atuin binary.
# On first run (no atuin DB yet), the existing zsh history is auto-imported.

if [ "$ATUIN_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

# Only meaningful in zsh (envi mandates zsh) and when the binary is present.
if [ -z "$ZSH_VERSION" ] || ! command -v atuin >/dev/null 2>&1; then
    return 0 2>/dev/null || exit 0
fi

# Atuin's widgets need ZLE, which only exists in interactive shells.
case "$-" in
    *i*) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac

# One-time import of the existing zsh history into atuin's DB.
ATUIN_DB="${XDG_DATA_HOME:-$HOME/.local/share}/atuin/history.db"
if [ ! -f "$ATUIN_DB" ]; then
    atuin import auto >/dev/null 2>&1 || true
fi

# Install envi's default config on first run (compact inline TUI).
# Never overwrites an existing user config.
ATUIN_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/atuin"
if [ ! -f "$ATUIN_CFG_DIR/config.toml" ] && [ -f "$ENVI_HOME/integrations/atuin/config.toml" ]; then
    mkdir -p "$ATUIN_CFG_DIR"
    cp "$ENVI_HOME/integrations/atuin/config.toml" "$ATUIN_CFG_DIR/config.toml"
fi

# Binds Up-arrow and Ctrl+R to the atuin search TUI.
eval "$(atuin init zsh)"
