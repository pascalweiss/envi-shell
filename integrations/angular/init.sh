#!/usr/bin/env bash
#
# ANGULAR CLI INITIALIZATION
# ===========================
# Angular CLI completions for zsh
# Only loads if ng command is available

# Load Angular CLI completion (requires Oh-My-Zsh completion system).
# Cached to disk and refreshed when the ng binary is updated.
if [ -n "${ZSH_VERSION:-}" ] && [ -n "$ZSH" ] && typeset -f compdef >/dev/null 2>&1; then
    _envi_ng_bin="$(command -v ng 2>/dev/null)"
    if [ -n "$_envi_ng_bin" ]; then
        _envi_ng_cache="${XDG_CACHE_HOME:-$HOME/.cache}/envi/ng-completion.zsh"
        if [ ! -s "$_envi_ng_cache" ] || [ "$_envi_ng_bin" -nt "$_envi_ng_cache" ]; then
            mkdir -p "${_envi_ng_cache%/*}"
            "$_envi_ng_bin" completion script >"$_envi_ng_cache.tmp.$$" 2>/dev/null \
                && mv "$_envi_ng_cache.tmp.$$" "$_envi_ng_cache" \
                || rm -f "$_envi_ng_cache.tmp.$$"
        fi
        [ -s "$_envi_ng_cache" ] && source "$_envi_ng_cache" 2>/dev/null || true
        unset _envi_ng_cache
    fi
    unset _envi_ng_bin
fi
