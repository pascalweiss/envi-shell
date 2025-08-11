#!/usr/bin/env bash
#
# FLUX INITIALIZATION
# ===================
# Flux CLI completions for zsh
# Only loads if flux command is available

# Load Flux CLI completion (requires Oh-My-Zsh completion system)
if [ -n "$ZSH" ] && typeset -f compdef >/dev/null 2>&1; then
    if command -v flux >/dev/null 2>&1; then
        . <(flux completion zsh)
    fi
fi