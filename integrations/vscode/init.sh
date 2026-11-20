#!/usr/bin/env bash
#
# VS CODE INITIALIZATION
# ======================
# Installs the envi-tracked `pweiss.markdown-colors` extension into
# ~/.vscode/extensions/ and registers it in ~/.vscode/extensions/extensions.json
# so VS Code's built-in Markdown preview uses the shared color stylesheet
# across all workspaces without touching per-machine settings.json files.
#
# Why copies instead of symlinks inside the extension folder:
# VS Code's webview resource server resolves symlinks via fs.realpath before
# checking whether a file sits inside an allowed localResourceRoot. A symlink
# pointing out of ~/.vscode/extensions/ into ~/.envi/ fails that check with
# 401 Unauthorized. We therefore copy package.json and markdown.css whenever
# the tracked files change.
#
# Why extensions.json registration is required:
# Modern VS Code no longer auto-discovers arbitrary folders dropped into
# ~/.vscode/extensions/ on every startup; it reads extensions.json as its
# manifest of installed extensions.
#
# Controlled via VSCODE_ENABLED (default: true).

: "${VSCODE_ENABLED:=true}"
export VSCODE_ENABLED

if [ "$VSCODE_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

_envi_sync_vscode_markdown_colors() {
    local src_dir="$ENVI_HOME/integrations/vscode/markdown-colors"
    local ext_root="$HOME/.vscode/extensions"
    local ext_rel="pweiss.markdown-colors-1.0.0"
    local dst_dir="$ext_root/$ext_rel"
    local manifest="$ext_root/extensions.json"
    local f entry

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

    # Register in ~/.vscode/extensions/extensions.json if not already present.
    if [ ! -f "$manifest" ]; then
        printf '[%s]\n' "$(_envi_vscode_manifest_entry "$dst_dir" "$ext_rel")" > "$manifest"
    elif ! grep -q '"pweiss.markdown-colors"' "$manifest" 2>/dev/null; then
        entry="$(_envi_vscode_manifest_entry "$dst_dir" "$ext_rel")"
        if command -v jq >/dev/null 2>&1; then
            jq --argjson e "$entry" '. + [$e]' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
        elif command -v python3 >/dev/null 2>&1; then
            python3 -c '
import json, sys
path, entry = sys.argv[1], json.loads(sys.argv[2])
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
data.append(entry)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, separators=(",", ":"))
' "$manifest" "$entry"
        fi
    fi
}

_envi_vscode_manifest_entry() {
    local dst_dir="$1"
    local ext_rel="$2"
    printf '{"identifier":{"id":"pweiss.markdown-colors"},"version":"1.0.0","location":{"$mid":1,"fsPath":"%s","external":"file://%s","path":"%s","scheme":"file"},"relativeLocation":"%s"}' \
        "$dst_dir" "$dst_dir" "$dst_dir" "$ext_rel"
}

_envi_sync_vscode_markdown_colors
unset -f _envi_sync_vscode_markdown_colors _envi_vscode_manifest_entry
