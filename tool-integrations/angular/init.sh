#!/usr/bin/env bash
#
# ANGULAR CLI INITIALIZATION
# ===========================
# Angular CLI completions for zsh
# Only loads if ng command is available

# Load Angular CLI completion (requires Oh-My-Zsh completion system)
if [ -n "$ZSH" ] && typeset -f compdef >/dev/null 2>&1; then
    if command -v ng >/dev/null 2>&1; then
        . <(ng completion script)
    fi
fi