#!/usr/bin/env bash
#
# ZOXIDE INITIALIZATION
# =====================
# zoxide is a smarter `cd`: it ranks directories by frequency + recency, so
# `z foo` jumps to the most-frecent path matching "foo" from anywhere.
# `zi` opens an interactive fzf picker over all known directories.
#
# Controlled via ZOXIDE_ENABLED (default: true). No-op if zoxide is not
# installed.

: "${ZOXIDE_ENABLED:=true}"
export ZOXIDE_ENABLED

if [ "$ZOXIDE_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v zoxide >/dev/null 2>&1; then
    return 0 2>/dev/null || exit 0
fi

if [ -n "$ZSH_VERSION" ]; then
    eval "$(zoxide init zsh)"
elif [ -n "$BASH_VERSION" ]; then
    eval "$(zoxide init bash)"
fi
