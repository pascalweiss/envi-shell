#!/usr/bin/env bash

# Place for default shortcuts, that should be available on every system, where envi is installed.

alias envi="cd \$ENVI_HOME"
alias loc="vim ~/.envi_locations"
alias environ="vim ~/.envi_env"
alias short="vim ~/.envi_shortcuts"

alias py2="python2"
alias py3="python3"
alias ipy="ipython"
alias python="python3"

alias clr="clear"

if command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi
if [[ "$(uname)" = *Linux* ]]; then
    alias o='open'
    alias o.='open .'
elif [[ "$(uname)" = *Darwin* ]]; then
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
mkcd (){
    mkdir -p -- "${1}" &&
      cd -P -- "${1}" || return
}
