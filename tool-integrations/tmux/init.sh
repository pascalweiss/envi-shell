#!/usr/bin/env bash
#
# TMUX INITIALIZATION
# ===================
# Tmux session management and auto-start functionality
# Called from envi_post_init for interactive shells only

# Tmux auto-start (only for interactive shells)
if [ "$TMUX_ENABLED" = "true" ] && [ -z "$TMUX" ] && [ -n "$PS1" ]; then
    if command -v tmux &> /dev/null; then
        # Check if there are existing sessions and auto-attach is enabled
        if [ "$TMUX_AUTO_ATTACH" = "true" ] && tmux list-sessions &>/dev/null; then
            echo "Attaching to existing tmux session..."
            if [ "$TMUX_SHOW_HELP" = "true" ]; then
                tmux attach-session \; send-keys 'tmux-help' C-m
            else
                tmux attach-session
            fi
        else
            echo "Starting new tmux session..."
            if [ "$TMUX_SHOW_HELP" = "true" ]; then
                tmux new-session \; send-keys 'tmux-help' C-m
            else
                tmux new-session
            fi
        fi
    fi
fi