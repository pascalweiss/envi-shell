#!/usr/bin/env bash
#
# HOMEBREW INITIALIZATION
# =======================
# Homebrew package manager integration and environment setup
# Auto-detects Homebrew installation and loads environment

# Homebrew Integration
# Configure environment based on available Homebrew installation paths without
# forking `brew shellenv` (~40ms) on every shell startup. Check macOS paths
# first so macOS never stats `/home/...` (which triggers the macOS automounter
# on `/home` and costs ~25ms on every shell start).
_envi_brew_prefix=""
if [ -x "/opt/homebrew/bin/brew" ]; then
    _envi_brew_prefix="/opt/homebrew"
elif [ -x "/usr/local/bin/brew" ]; then
    _envi_brew_prefix="/usr/local"
elif [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    _envi_brew_prefix="/home/linuxbrew/.linuxbrew"
fi

if [ -n "$_envi_brew_prefix" ]; then
    export HOMEBREW_PREFIX="$_envi_brew_prefix"
    export HOMEBREW_CELLAR="$_envi_brew_prefix/Cellar"
    export HOMEBREW_REPOSITORY="$_envi_brew_prefix"
    case ":$PATH:" in
        *":$_envi_brew_prefix/bin:"*) ;;
        *) export PATH="$_envi_brew_prefix/bin:$_envi_brew_prefix/sbin${PATH+:$PATH}" ;;
    esac
    case ":${INFOPATH:-}:" in
        *":$_envi_brew_prefix/share/info:"*) ;;
        *) export INFOPATH="$_envi_brew_prefix/share/info:${INFOPATH:-}" ;;
    esac
    if [ -n "${ZSH_VERSION:-}" ]; then
        # Add site-functions to zsh's fpath array without exporting FPATH into
        # the environment (exporting FPATH causes tmux to inherit post-compinit
        # fpath mutations and bust Oh-My-Zsh's zcompdump cache on every new pane).
        typeset -g +x FPATH 2>/dev/null || true
        case " ${fpath[*]} " in
            *" $_envi_brew_prefix/share/zsh/site-functions "*) ;;
            *) fpath=("$_envi_brew_prefix/share/zsh/site-functions" $fpath) ;;
        esac
    fi
fi
unset _envi_brew_prefix

# macOS blocks a node whose signature it has no Local Network decision for, and every Homebrew
# node arrives with a new one. Re-sign it right after brew changes packages, so the permission
# granted once stays valid (see executables/macbin/node-local-network).
# The lookup happens per call: envi may put macbin on the PATH after this file has run.
if [[ "${OSTYPE:-$(uname -s)}" == [Dd]arwin* ]]; then
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
