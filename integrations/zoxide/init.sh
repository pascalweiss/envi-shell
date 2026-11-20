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

_envi_zoxide_bin="$(command -v zoxide 2>/dev/null)"
if [ -z "$_envi_zoxide_bin" ]; then
    unset _envi_zoxide_bin
    return 0 2>/dev/null || exit 0
fi

if [ -n "$ZSH_VERSION" ]; then
    _envi_zoxide_cache="${XDG_CACHE_HOME:-$HOME/.cache}/envi/zoxide-init.zsh"
    if [ ! -s "$_envi_zoxide_cache" ] || [ "$_envi_zoxide_bin" -nt "$_envi_zoxide_cache" ]; then
        mkdir -p "${_envi_zoxide_cache%/*}"
        "$_envi_zoxide_bin" init zsh >"$_envi_zoxide_cache.tmp.$$" 2>/dev/null \
            && mv "$_envi_zoxide_cache.tmp.$$" "$_envi_zoxide_cache" \
            || rm -f "$_envi_zoxide_cache.tmp.$$"
    fi
    if [ -s "$_envi_zoxide_cache" ]; then
        source "$_envi_zoxide_cache"
    else
        eval "$("$_envi_zoxide_bin" init zsh)"
    fi
    unset _envi_zoxide_cache
elif [ -n "$BASH_VERSION" ]; then
    eval "$("$_envi_zoxide_bin" init bash)"
fi
unset _envi_zoxide_bin
