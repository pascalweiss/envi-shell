#!/usr/bin/env bash

source $DIR/setup/console_output.sh
INSTALLED_PACKAGES=""
SYSTEM_NAME=$(uname)
#              _     _ _
#  _ __  _   _| |__ | (_) ___
# | '_ \| | | | '_ \| | |/ __|
# | |_) | |_| | |_) | | | (__
# | .__/ \__,_|_.__/|_|_|\___|
# |_|

function update_package_manager () {
    if [ -f "/proc/version" ]; then DEBIAN_FRONTEND=noninteractive sudo apt-get update --qq < /dev/null &> /dev/null;
    elif [ -d "/System" ]; then
        if [ ! `command -v brew` ]; then brew_install; fi
        brew update
    fi
}

function install_dependencies () {
    readarray PACKAGES < "$DIR/setup/dependencies.txt"
    print_packages "dependencies" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_packages () {
    readarray PACKAGES < "$DIR/config/packages_os.txt"
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_python () {
    PACKAGES=("python3" "python3-pip")
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}

function install_oh_my_zsh () {
    PACKAGES=("zsh")
    print_packages "OS packages" "${PACKAGES[@]}"
    install_all "${PACKAGES[@]}"
}


#             _            _
#  _ __  _ __(_)_   ____ _| |_ ___
# | '_ \| '__| \ \ / / _` | __/ _ \
# | |_) | |  | |\ V / (_| | ||  __/
# | .__/|_|  |_| \_/ \__,_|\__\___|
# |_|

function brew_install () {
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

function check_installation () {

    if [ "$INSTALLED_PACKAGES" = "" ]; then
        if [[ "$SYSTEM_NAME" = *Linux* ]]; then INSTALLED_PACKAGES=$(apt list --installed); 
        elif [[ "$SYSTEM_NAME" = *Darwin* ]]; then INSTALLED_PACKAGES=$(brew list);
        fi
    fi
    if [ `command -v $1` ]; then return 1; 
    else
        if [[ "$SYSTEM_NAME" = *Linux* ]]; then
            return $(echo $INSTALLED_PACKAGES | grep -c "$1")
        elif [[ "$SYSTEM_NAME" = *Darwin* ]]; then
            for item in ${INSTALLED_PACKAGES[@]}; do
                if [[ "$item" = *$1* ]]; then
                    return 1
                fi
            done
            return 0
        fi
    fi
}

function exec_install () {
    local ERROR
    check_installation $1
    INSTALLED=$?
    if [ $INSTALLED = 0 ]; then
        if [ -f "/proc/version" ]; then
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq $1 < /dev/null &> /dev/null
            ERROR=$?
        elif [ -d "/System" ]; then
            HOMEBREW_NO_AUTO_UPDATE=1 brew install $1 
            ERROR=$?
        fi
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