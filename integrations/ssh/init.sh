#!/usr/bin/env bash
#
# SSH INITIALIZATION
# ==================
# SSH agent management and auto-start functionality
# Called from enviinit for all shells

: "${SSH_AGENT_ENABLED:=true}"
export SSH_AGENT_ENABLED

# SSH Agent management (interactive shells only)
if [ "$SSH_AGENT_ENABLED" = "true" ] && [ -z "$SSH_AUTH_SOCK" ] && [ -n "$PS1" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
fi

# Connection multiplexing (ControlMaster) — see integrations/ssh/config.
# Enables `erun` to reuse the user's interactive ssh sessions. Controlled via
# SSH_MULTIPLEX_ENABLED (default: true). Wiring is idempotent and cheap.
: "${SSH_MULTIPLEX_ENABLED:=true}"
export SSH_MULTIPLEX_ENABLED

if [ "$SSH_MULTIPLEX_ENABLED" = "true" ]; then
    # Directory that holds the master sockets (referenced by integrations/ssh/config).
    [ -d "$HOME/.ssh/cm" ] || mkdir -p "$HOME/.ssh/cm"
    chmod 700 "$HOME/.ssh" "$HOME/.ssh/cm" 2>/dev/null

    # Ensure ~/.ssh/config includes the envi-managed multiplexing block. It MUST
    # be prepended (before any Host/Match block): an Include placed after a Host
    # block is nested inside that block's context and only applies to that host,
    # so a trailing include would silently do nothing for every other host.
    _envi_ssh_include="Include $ENVI_HOME/integrations/ssh/config"
    if [ ! -f "$HOME/.ssh/config" ]; then
        printf '%s\n' "$_envi_ssh_include" > "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    elif ! grep -qF "$_envi_ssh_include" "$HOME/.ssh/config" 2>/dev/null; then
        _envi_ssh_tmp="$HOME/.ssh/.config.envitmp.$$"
        { printf '%s\n\n' "$_envi_ssh_include"; cat "$HOME/.ssh/config"; } > "$_envi_ssh_tmp" \
            && chmod 600 "$_envi_ssh_tmp" \
            && mv "$_envi_ssh_tmp" "$HOME/.ssh/config"
        rm -f "$_envi_ssh_tmp" 2>/dev/null
        unset _envi_ssh_tmp
    fi
    unset _envi_ssh_include
fi