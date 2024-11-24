#!/usr/bin/env bash


source "${DIR}"/setup/_func_console_output.sh


function install_packages () {
    readarray -t PY_PACKAGES < "${DIR}/defaults/packages_python.txt"
    print_packages "Python packages" "${PY_PACKAGES[@]}"
    install_all "${PY_PACKAGES[@]}"
}

function check_installation() {
  pipx list --json | jq -r '.venvs | keys[]' | grep -q "^$1$"
}

function exec_install () {
    local ERROR
    local INSTALLED
    check_installation "${1}"
    INSTALLED=$?
    if [ $INSTALLED -ne 0 ]; then
        pipx install -q "${1}" < /dev/null &> /dev/null
        ERROR=$?
        install_error_print "${1}" "$ERROR"
    else
        echo -e "${GREEN}Already installed: ${1}${NC}"
    fi
}

function install_all () {
    for P in "${@}"; do
        exec_install "${P}"
    done
}