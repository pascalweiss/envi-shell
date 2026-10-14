#!/usr/bin/env bash
#
# ITERM2 INITIALIZATION
# ======================
# iTerm2's "Install Shell Integration" menu item drops a shell script at
# ~/.iterm2_shell_integration.zsh and normally appends a source line for
# it straight into ~/.zshrc. envi keeps that out of the zshrc and sources
# it here instead, and only when the shell actually runs inside iTerm2:
# TERM_PROGRAM covers a plain iTerm2 window, LC_TERMINAL is what iTerm2
# propagates into tmux panes (TERM_PROGRAM itself gets lost there).
#
# The integration script itself is not envi-tracked: it is installed and
# updated by iTerm2, machine-local, so this only conditionally sources it
# if present rather than symlinking an envi-owned copy (same pattern as
# ghostty/alacritty, minus the config file).
#
# Controlled via ITERM2_ENABLED (default: true). No-op on Linux and
# whenever the current terminal is not iTerm2 or the script is missing.

: "${ITERM2_ENABLED:=true}"
export ITERM2_ENABLED

if [ "$ITERM2_ENABLED" != "true" ]; then
    return 0 2>/dev/null || exit 0
fi

# iTerm2 is macOS-only.
if [ "$(uname)" != "Darwin" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ "$TERM_PROGRAM" != "iTerm.app" ] && [ "$LC_TERMINAL" != "iTerm2" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then
    source "$HOME/.iterm2_shell_integration.zsh"
fi
