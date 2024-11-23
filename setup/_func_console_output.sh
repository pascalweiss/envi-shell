#!/usr/bin/env bash

function install_error_print () {
    if (( $2 == 0 )); then echo "Installation successful: $1"; 
    else echo "Installation not successful: $1"
    fi
}

function print_packages () {
    NAME=$1
    shift
    i=0
    printf "\nTry to install the following $NAME: "
    for P in "$@"; do
        P=$(echo "$P" | sed 's/[[:space:]]//g')
        if (( $i == 0 )); then
            printf -- "\n$P"
        else 
            printf -- ", $P"
        fi
        i=$(expr $i + 1)
    done
    printf "\n\n"
}
