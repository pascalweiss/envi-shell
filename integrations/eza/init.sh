#!/usr/bin/env bash
#
# EZA INITIALIZATION
# ==================
# eza is a modern `ls` replacement with git status, icons, tree view.
# This integration installs convenience aliases.
#
# Controlled via EZA_ENABLED (default: true). No-op if eza is not
# installed.

if [ "$EZA_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v eza >/dev/null 2>&1; then
    return 0 2>/dev/null || exit 0
fi

alias ls='eza'
alias ll='eza -l --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'
