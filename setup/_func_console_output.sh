#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function install_error_print () {
    if (( $2 == 0 )); then echo -e "${GREEN}Installation successful: ${1}${NC}";
    else echo -e "${RED}Installation not successful: ${1}${NC}"
    fi
}

function print_packages () {
    NAME="${1}"
    shift
    i=0
    printf "\n${BLUE}Try to install the following ${NAME}: "
    for P in "$@"; do
        P=$(echo -e "$P" | sed 's/[[:space:]]//g')
        if (( $i == 0 )); then
            printf -- "\n$P"
        else 
            printf -- ", $P"
        fi
        i=$(expr $i + 1)
    done
    printf "${NC}\n\n"
}
