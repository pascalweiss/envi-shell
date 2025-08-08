#!/usr/bin/env bash
#
# ENVI DEFAULT SHORTCUTS
# ======================
# Default shortcuts and aliases - copied to ~/.envi/config/.envi_shortcuts during setup
# User config overrides these defaults. See CLAUDE.md for loading order details.
# NOTE: Core envi aliases (envi, loc, environ, short) are hardcoded in enviinit

# Python shortcuts
alias py2="python2"
alias py3="python3"
alias ipy="ipython"
alias python="python3"

# Terminal utilities
alias clr="clear"

# Network utilities
alias pingg="ping -i 0.2 1.1.1.1"

# Tmux shortcuts
alias tl="tmux list-sessions"
ta() { tmux attach-session -t "$1"; }
tk() { tmux kill-session -t "$1"; }

# Shell shortcuts
alias execz="exec zsh"

# Bat command compatibility (Ubuntu uses batcat)
if command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi

# Platform-specific shortcuts

if [[ "$(uname)" = *Linux* ]]; then
    # Linux-specific aliases
    alias o='open'
    alias o.='open .'
elif [[ "$(uname)" = *Darwin* ]]; then
    # macOS-specific aliases and functions
    openFile() {
            open $1
    }
    alias o=openFile
    alias "o."='open .'
    alias pre="qlmanage -p "
    alias doc="cd \$HOME/Documents"
    alias odoc="open \$HOME/Documents"
    alias vol="cd /Volumes"
fi

# Utility functions

# Create directory and navigate to it
mkcd (){
    mkdir -p -- "${1}" &&
      cd -P -- "${1}" || return
}
