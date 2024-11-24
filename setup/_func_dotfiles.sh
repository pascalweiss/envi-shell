#!/usr/bin/env bash

BACKUP_DIR="$HOME/dotfiles_backup"

function backup_file () {
    # if the backupfolder doesn't exist, remove it
    if [ ! -d "$2" ]; then mkdir $2; fi
    # if $1 is a symlink remove it
    if [ -L $1 ]; then rm $1; fi
    # if $1 is a file or directory, create a backup. We will add it later again
    if [[ -f "${1}" || -d "${1}" ]]; then mv $1 $2; fi
}

function replace_bashrc () {
    backup_file "$HOME/.bashrc" $BACKUP_DIR
    add_symlink "$DIR/submodules/dotfiles/.bashrc" "$HOME/.bashrc"
}

function replace_zshrc () {
    backup_file "$HOME/.zshrc" $BACKUP_DIR
    add_symlink "$DIR/submodules/dotfiles/.zshrc" "$HOME/.zshrc"
}

function replace_vim () {
    backup_file "$HOME/.vim" $BACKUP_DIR
    add_symlink "$DIR/submodules/envi-vim/.vim" "$HOME/.vim"

    backup_file "$HOME/.vimrc" $BACKUP_DIR
    add_symlink "$DIR/submodules/envi-vim/.vimrc" "$HOME/.vimrc"
}
