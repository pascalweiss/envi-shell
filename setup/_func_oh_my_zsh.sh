#!/usr/bin/env bash

function install_packages () {
    
    curl -Lo /tmp/oh_my_install.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
    sh /tmp/oh_my_install.sh --unattended
    rm /tmp/oh_my_install.sh
}