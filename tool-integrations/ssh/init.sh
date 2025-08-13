#!/usr/bin/env bash
#
# SSH INITIALIZATION
# ==================
# SSH agent management and auto-start functionality
# Called from enviinit for all shells

# SSH Agent management (interactive shells only)
if [ "$SSH_AGENT_ENABLED" = "true" ] && [ -z "$SSH_AUTH_SOCK" ] && [ -n "$PS1" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
fi