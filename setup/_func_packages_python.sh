#!/usr/bin/env bash


source "${DIR}"/setup/_func_console_output.sh


function install_packages () {
    readarray -t PY_PACKAGES < "${DIR}/defaults/packages_python.txt"
    print_packages "Python packages" "${PY_PACKAGES[@]}"
    install_all "${PY_PACKAGES[@]}"
}

function check_installation () {
    return $(pipx list --format=freeze | grep -c "^${1}==")
}

function exec_install () {
    local ERROR
    check_installation
    INSTALLED=$?
    if [ $INSTALLED = 0 ]; then
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