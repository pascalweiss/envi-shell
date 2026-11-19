#!/usr/bin/env bash
#
# WEZTERM INITIALIZATION
# ======================
# Symlinks ~/.config/wezterm/wezterm.lua to the envi-tracked config (same
# pattern as ghostty) and provides `tabcolor`, which colors the current
# WezTerm tab from the shell, also from inside tmux.
#
# Controlled via WEZTERM_ENABLED (default: true).

: "${WEZTERM_ENABLED:=true}"
export WEZTERM_ENABLED

if [ "$WEZTERM_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -f "$ENVI_HOME/integrations/wezterm/wezterm.lua" ]; then
    link_with_backup "$ENVI_HOME/integrations/wezterm/wezterm.lua" \
        "${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.lua"
fi

# tabcolor <color> [title]
#   color: a number 1-9 (same order as the Cmd+Alt+C picker), a name
#          red|orange|yellow|green|teal|blue|purple|pink|gray, #rrggbb, off,
#          or - to keep the current color and only set the title
#   tabcolor without arguments lists the numbers
#   title: optional tab name; "" clears it, so the tab shows the pane title again
# Sets the WezTerm user vars tab_color and tab_title. Inside tmux the sequences
# are written straight to the client's terminal, so tmux needs no passthrough.
_wezterm_user_var() {
    local seq
    seq=$(printf '\033]1337;SetUserVar=%s=%s\007' "$1" "$(printf '%s' "$2" | base64)")
    if [ -n "$TMUX" ]; then
        printf '%s' "$seq" > "$(tmux display -p '#{client_tty}')"
    else
        printf '%s' "$seq"
    fi
}

tabcolor() {
    local color="$1" i=0 name
    if [ $# -eq 0 ]; then
        echo "usage: tabcolor <number|name|#rrggbb|-|off> [title]" >&2
        for name in red orange yellow green teal blue purple pink gray; do
            i=$((i + 1)); echo "  $i $name" >&2
        done
        return 1
    fi
    case "$color" in
        [1-9])
            for name in red orange yellow green teal blue purple pink gray; do
                i=$((i + 1)); [ "$i" = "$color" ] && color=$name
            done ;;
    esac
    [ "$color" != "-" ] && _wezterm_user_var tab_color "$color"
    [ $# -ge 2 ] && _wezterm_user_var tab_title "$2"
    return 0
}

# tabname [title]
# Names the current WezTerm tab; without an argument the name is removed and
# the tab shows the pane title again. Same as `tabcolor - <title>`.
tabname() {
    _wezterm_user_var tab_title "${1:-}"
}

# wezterm-help
# Prints the WezTerm shortcuts and these commands. The list is written by
# wezterm.lua whenever WezTerm loads its config, so it always matches it.
wezterm-help() {
    local f="$HOME/.cache/envi-wezterm-help.txt"
    if [ -f "$f" ]; then
        cat "$f"
    else
        echo "No help yet: $f is written when WezTerm loads its config." >&2
        return 1
    fi
}
