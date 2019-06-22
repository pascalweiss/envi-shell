#!/usr/bin/env bash

function install_packages () {
    os_package_install "zsh"
    curl -Lo oh_my_install.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
    sh oh_my_install.sh --unattended
    rm oh_my_install.sh
}