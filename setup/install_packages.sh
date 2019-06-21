#!/usr/bin/env bash

function brew_install () {
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

function os_packagemanager_update () {
    if [ -f "/proc/version" ]; then apt-get update;
    elif [ -d "/System" ]; then
        if [ ! `command -v brew` ]; then install_brew; fi
        brew update
    fi
}

function os_package_install () {
    if [ -f "/proc/version" ]; then
        apt install -y $1 
        echo "installed $1"
    elif [ -d "/System" ]; then
        HOMEBREW_NO_AUTO_UPDATE=1 brew install $1 
    fi
}

function exec_os_packages_install () {
    #os_packagemanager_update
    readarray PACKAGES < "$1"
    echo "will install the following dependencies: " 
    echo "${PACKAGES[@]}"
    for P in "${PACKAGES[@]}"; do
        os_package_install $PACKAGE || true
    done
}

function os_packages_install () {
    exec_os_packages_install "$DIR/config/packages_os.txt"
}

function os_dependencies_install() {
    exec_os_packages_install "$DIR/setup/dependencies.txt"   
}

function python_packages_install () {
    if [ ! `command -v pip3` ]; then
        if [[ "$(uname)" = *Darwin* ]]; then brew install python3-pip
        elif [[ "$(unamme)" = *Linux* ]]; then apt install python3-pip
        fi
    fi
    pip3 install -r $DIR/config/packages_python.txt
}

function oh_my_zsh_install () {
    os_package_install "zsh"
    curl -Lo install_oh_my_zsh.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
    bash install_oh_my_zsh.sh --unattended
}