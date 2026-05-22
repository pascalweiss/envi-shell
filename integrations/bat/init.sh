#!/usr/bin/env bash
#
# BAT INITIALIZATION
# ==================
# bat is a `cat` clone with syntax highlighting and git integration.
# This integration wires it up as MANPAGER so `man <cmd>` renders with
# syntax highlighting.
#
# Controlled via BAT_ENABLED (default: true). No-op if bat is not
# installed. On Ubuntu the binary is `batcat`; we handle both.

: "${BAT_ENABLED:=true}"
export BAT_ENABLED

if [ "$BAT_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

if command -v bat >/dev/null 2>&1; then
    _envi_bat_bin="bat"
elif command -v batcat >/dev/null 2>&1; then
    _envi_bat_bin="batcat"
else
    return 0 2>/dev/null || exit 0
fi

# MANROFFOPT=-c keeps groff color escapes alive so bat can re-style them.
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | ${_envi_bat_bin} -l man -p'"

unset _envi_bat_bin
