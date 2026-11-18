#!/usr/bin/env bash
#
# HOMEBREW INITIALIZATION
# =======================
# Homebrew package manager integration and environment setup
# Auto-detects Homebrew installation and loads environment

# Homebrew Integration
# Configure environment based on available Homebrew installation paths
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# macOS blocks a node whose signature it has no Local Network decision for, and every Homebrew
# node arrives with a new one. Re-sign it right after brew changes packages, so the permission
# granted once stays valid (see executables/macbin/node-local-network).
# The lookup happens per call: envi may put macbin on the PATH after this file has run.
if [ "$(uname -s)" = Darwin ]; then
    brew() {
        command brew "$@"
        local rc=$?
        case "${1:-}" in
            install|upgrade|reinstall)
                command -v node-local-network >/dev/null 2>&1 && node-local-network --quiet ;;
        esac
        return $rc
    }
fi
