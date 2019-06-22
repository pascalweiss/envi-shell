#!/usr/bin/env bash

function install_dialog () {
    local POS_FLAG=$1 NEG_FLAG=$2 QUESTION=$3 FUNC=$4
    for((i=0;i<4;i++)); do shift; done
    if contains "$POS_FLAG" "$@"; then INSTALL_PACKAGES=true;
    elif contains "$NEG_FLAG" "$@" ; then INSTALL_PACKAGES=false
    else 
        read -ep "$QUESTION" ANSWER
        if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then INSTALL_PACKAGES=true; 
        else INSTALL_PACKAGES=false; fi
    fi
    if $INSTALL_PACKAGES; then 
        eval $FUNC
    fi
}
