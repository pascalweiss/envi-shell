#!/usr/bin/env bash


source $DIR/setup/console_output.sh


#              _     _ _
#  _ __  _   _| |__ | (_) ___
# | '_ \| | | | '_ \| | |/ __|
# | |_) | |_| | |_) | | | (__
# | .__/ \__,_|_.__/|_|_|\___|
# |_|

function install_packages () {
    readarray PY_PACKAGES < "$DIR/config/packages_python.txt"
    print_packages "Python packages" "${PY_PACKAGES[@]}"
    install_all "${PY_PACKAGES[@]}"
}

function check_installation () {
    return $(pip3 list --format=freeze | grep -c "^$1==")
}

function exec_install () {
    local ERROR
    check_installation
    INSTALLED=$?
    if [ $INSTALLED = 0 ]; then
        pip3 install -q "$1" < /dev/null &> /dev/null
        ERROR=$?
        install_error_print $1 $ERROR
    else
        echo "Already installed: $1"
    fi
}

function install_all () {
    for P in "$@"; do
        exec_install $P 
    done
}