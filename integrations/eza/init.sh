#!/usr/bin/env bash
#
# EZA INITIALIZATION
# ==================
# eza is a modern `ls` replacement with git status, icons, tree view.
# This integration installs convenience aliases.
#
# Controlled via EZA_ENABLED (default: true). No-op if eza is not
# installed.

: "${EZA_ENABLED:=true}"
export EZA_ENABLED

if [ "$EZA_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v eza >/dev/null 2>&1; then
    return 0 2>/dev/null || exit 0
fi

# Suppress eza's default background highlights on special files. Without
# this, `ls /dev` is a wall of solid color blocks because almost every
# entry is a block/char device, socket, or fifo.
export EZA_COLORS="bd=33:cd=33:so=35:pi=33:or=31"

alias ls='eza'
alias ll='eza -l --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias lt='eza --tree --level=2 --group-directories-first'
