#!/usr/bin/env bash

BACKUP_DIR="$HOME/dotfiles_backup"

function backup_file () {
    if [ ! -d "$2" ]; then
        mkdir $2
    fi
    if [ -L $1 ]; then 
        rm $1           # if $FILE is a symlink remove it
    elif [ -f $FILE ]; then
        mv $1 $2      # if $FILE is a file, create a backup. We will add it later again
    fi
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
    add_symlink "$DIR/submodules/dotfiles/.vim" "$HOME/.vim"

    backup_file "$HOME/.vimrc" $BACKUP_DIR
    add_symlink "$DIR/submodules/dotfiles/.vimrc" "$HOME/.vimrc"
}
