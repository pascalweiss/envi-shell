#!/usr/bin/env bash
#
# FLUX INITIALIZATION
# ===================
# Flux CLI completions for zsh
# Only loads if flux command is available

# Load Flux CLI completion (requires Oh-My-Zsh completion system)
if [ -n "$ZSH" ] && typeset -f compdef >/dev/null 2>&1; then
    if command -v flux >/dev/null 2>&1; then
        # Suppress errors from flux completion as it may have compatibility issues
        . <(flux completion zsh 2>/dev/null) 2>/dev/null || true
    fi
fi