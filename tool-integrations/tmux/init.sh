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

        # Check if tmux session chooser is requested
        # Set LC_IDENTIFICATION=tmux-menu to trigger (passes through SSH via AcceptEnv LC_*)
        if [[ "$LC_IDENTIFICATION" == tmux-menu* ]]; then
            if tmux list-sessions &>/dev/null; then
                # Attach to first session and immediately show native tmux chooser
                echo "Choose a tmux session:"
                tmux -f "$TMUX_CONFIG_FILE" attach-session \; choose-tree -Z -F '#{?pane_format,#[fg=colour228]#{pane_current_command} #[fg=colour59]│ #[fg=colour114]#{s|$HOME|~|:pane_current_path},#{?window_format,#[fg=colour117]#{window_name}#{window_flags},#[fg=colour39]#{session_name} (#{session_windows})}}'
            else
                # No existing sessions, create a new one
                echo "No existing sessions. Starting new tmux session..."
                tmux -f "$TMUX_CONFIG_FILE" new-session
            fi
        # Check if there are existing sessions and auto-attach is enabled
        elif [ "$TMUX_AUTO_ATTACH" = "true" ] && tmux list-sessions &>/dev/null; then
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