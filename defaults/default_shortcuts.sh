#!/usr/bin/env bash

alias loc='vim ~/.mega_locations'
alias short='vim ~/.mega_shortcuts'
alias py2="python2"
alias py3="python3"
alias ipy='ipython'

if [[ "$uname" = *Linux* ]]; then
    alias o='open'
    alias o.='open .'
elif [[ "$string" = *Darwin* ]]; then
    openFile() {
            open $1
    }
    alias o=openFile
    alias o='open'
    alias pre="qlmanage -p "
fi
mkcd (){
    mkdir -p -- "$1" &&
      cd -P -- "$1"
}
alias cal='gcal --starting-day=1'