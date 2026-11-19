#!/usr/bin/env bash
#
# VS CODE INITIALIZATION
# ======================
# Installs the envi-tracked `pweiss.markdown-colors` extension into
# ~/.vscode/extensions/ so VS Code's built-in Markdown preview uses the
# shared color stylesheet across all workspaces without touching per-machine
# settings.json files.
#
# Why copies instead of symlinks inside the extension folder:
# VS Code's webview resource server resolves symlinks via fs.realpath before
# checking whether a file sits inside an allowed localResourceRoot. A symlink
# pointing out of ~/.vscode/extensions/ into ~/.envi/ fails that check with
# 401 Unauthorized. We therefore copy package.json and markdown.css whenever
# the tracked files change.
#
# Controlled via VSCODE_ENABLED (default: true).

: "${VSCODE_ENABLED:=true}"
export VSCODE_ENABLED

if [ "$VSCODE_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

_envi_sync_vscode_markdown_colors() {
    local src_dir="$ENVI_HOME/integrations/vscode/markdown-colors"
    local dst_dir="$HOME/.vscode/extensions/pweiss.markdown-colors-1.0.0"
    local f

    [ -d "$src_dir" ] || return 0

    # Only install if VS Code has been used on this machine (~/.vscode exists)
    # or the `code` CLI is on PATH.
    if [ ! -d "$HOME/.vscode" ] && ! command -v code >/dev/null 2>&1; then
        return 0
    fi

    mkdir -p "$dst_dir"
    for f in package.json markdown.css; do
        if [ -f "$src_dir/$f" ]; then
            if [ -L "$dst_dir/$f" ] || [ ! -f "$dst_dir/$f" ] || ! cmp -s "$src_dir/$f" "$dst_dir/$f"; then
                rm -f "$dst_dir/$f"
                cp "$src_dir/$f" "$dst_dir/$f"
            fi
        fi
    done
}

_envi_sync_vscode_markdown_colors
unset -f _envi_sync_vscode_markdown_colors
