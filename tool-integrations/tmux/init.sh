#!/usr/bin/env bash
#
# TMUX INITIALIZATION
# ===================
# Tmux session management and auto-start functionality
# Called from enviinit for interactive shells only

# Tmux auto-start (only for interactive shells)
if [ "$TMUX_ENABLED" = "true" ] && [ -z "$TMUX" ] && [ -n "$PS1" ]; then
    if command -v tmux &> /dev/null; then
        # Use single tmux config for all terminal sizes
        TMUX_CONFIG_FILE="$HOME/.envi/tool-integrations/tmux/tmux.conf"
        
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