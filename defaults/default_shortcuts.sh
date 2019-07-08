#!/usr/bin/env bash

alias mega="cd $MEGA_HOME"
alias loc="vim ~/.mega_locations"
alias environ="vim ~/.mega_env"
alias short="vim ~/.mega_shortcuts"
alias py2="python2"
alias py3="python3"
alias ipy="ipython"

if [[ "$(uname)" = *Linux* ]]; then
    alias o='open'
    alias o.='open .'
elif [[ "$(uname)" = *Darwin* ]]; then
    openFile() {
            open $1
    }
    alias o=openFile
    alias "o."="open ."
    alias pre="qlmanage -p "
    alias doc="cd $HOME/Documents"
    alias odoc="open $HOME/Documents"
    alias vol="cd /Volumes"
fi
mkcd (){
    mkdir -p -- "$1" &&
      cd -P -- "$1"
}
