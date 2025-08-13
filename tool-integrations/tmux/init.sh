#!/usr/bin/env bash
#
# TMUX INITIALIZATION
# ===================
# Tmux session management and auto-start functionality
# Called from enviinit for interactive shells only

# Tmux auto-start (only for interactive shells)
if [ "$TMUX_ENABLED" = "true" ] && [ -z "$TMUX" ] && [ -n "$PS1" ]; then
    if command -v tmux &> /dev/null; then
        # Determine which tmux config to use based on terminal size
        TMUX_CONFIG_FILE=""
        TERMINAL_COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
        if [ "$TERMINAL_COLS" -lt 80 ]; then
            # Small terminal - use minimal config
            TMUX_CONFIG_FILE="$HOME/.envi/tool-integrations/tmux/tmux-small.conf"
        else
            # Regular or large terminal - use full config
            TMUX_CONFIG_FILE="$HOME/.envi/tool-integrations/tmux/tmux.conf"
        fi
        
        # Check if there are existing sessions and auto-attach is enabled
        if [ "$TMUX_AUTO_ATTACH" = "true" ] && tmux list-sessions &>/dev/null; then
            echo "Attaching to existing tmux session..."
            if [ "$TMUX_SHOW_HELP" = "true" ]; then
                tmux -f "$TMUX_CONFIG_FILE" attach-session \; send-keys 'tmux-help' C-m
            else
                tmux -f "$TMUX_CONFIG_FILE" attach-session
            fi
        else
            echo "Starting new tmux session..."
            if [ "$TMUX_SHOW_HELP" = "true" ]; then
                tmux -f "$TMUX_CONFIG_FILE" new-session \; send-keys 'tmux-help' C-m
            else
                tmux -f "$TMUX_CONFIG_FILE" new-session
            fi
        fi
    fi
fi