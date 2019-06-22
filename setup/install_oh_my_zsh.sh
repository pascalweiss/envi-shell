#!/usr/bin/env bash

function install_packages () {
    curl -Lo oh_my_install.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
    sh oh_my_install.sh --unattended
    rm oh_my_install.sh
}