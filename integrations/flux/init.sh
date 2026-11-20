#!/usr/bin/env bash
#
# FLUX INITIALIZATION
# ===================
# Flux CLI completions for zsh
# Only loads if flux command is available

# Load Flux CLI completion (requires Oh-My-Zsh completion system).
# Cached to disk and refreshed when the flux binary is updated, avoiding a
# ~30ms process fork on every new shell or tmux pane.
if [ -n "${ZSH_VERSION:-}" ] && [ -n "$ZSH" ] && typeset -f compdef >/dev/null 2>&1; then
    _envi_flux_bin="$(command -v flux 2>/dev/null)"
    if [ -n "$_envi_flux_bin" ]; then
        _envi_flux_cache="${XDG_CACHE_HOME:-$HOME/.cache}/envi/flux-completion.zsh"
        if [ ! -s "$_envi_flux_cache" ] || [ "$_envi_flux_bin" -nt "$_envi_flux_cache" ]; then
            mkdir -p "${_envi_flux_cache%/*}"
            "$_envi_flux_bin" completion zsh >"$_envi_flux_cache.tmp.$$" 2>/dev/null \
                && mv "$_envi_flux_cache.tmp.$$" "$_envi_flux_cache" \
                || rm -f "$_envi_flux_cache.tmp.$$"
        fi
        [ -s "$_envi_flux_cache" ] && source "$_envi_flux_cache" 2>/dev/null || true
        unset _envi_flux_cache
    fi
    unset _envi_flux_bin
fi
