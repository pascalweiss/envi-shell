#!/usr/bin/env bash

function install_packages () {
    curl -Lo /tmp/oh_my_install.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
    sh /tmp/oh_my_install.sh --unattended
    rm /tmp/oh_my_install.sh

    # Also install autosuggestions
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
}