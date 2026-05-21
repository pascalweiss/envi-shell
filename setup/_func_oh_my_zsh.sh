#!/usr/bin/env bash

function install_packages () {
    if [ ! -d "${ZSH:-$HOME/.oh-my-zsh}" ]; then
        curl -Lo /tmp/oh_my_install.sh https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh
        sh /tmp/oh_my_install.sh --unattended
        rm /tmp/oh_my_install.sh
    fi

    local plugins_dir="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins"

    # zsh-autosuggestions: ghosted inline suggestions from history.
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
    fi

    # fzf-tab: fzf-powered popup for zsh tab-completion.
    if [ ! -d "$plugins_dir/fzf-tab" ]; then
        git clone https://github.com/Aloxaf/fzf-tab "$plugins_dir/fzf-tab"
    fi
}