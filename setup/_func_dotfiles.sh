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

# Bashrc configuration removed - using zsh-only approach

function replace_zshrc () {
    backup_file "$HOME/.zshrc" $BACKUP_DIR
    add_symlink "$DIR/tool-integrations/zsh/zshrc" "$HOME/.zshrc"
}

# Vim configuration removed - using neovim with VIMINIT approach

function replace_gitconfig () {
    backup_file "$HOME/.gitconfig" $BACKUP_DIR
    add_symlink "$DIR/tool-integrations/git/gitconfig" "$HOME/.gitconfig"
}

function replace_tmux () {
    backup_file "$HOME/.tmux.conf" $BACKUP_DIR
    add_symlink "$DIR/tool-integrations/tmux/tmux.conf" "$HOME/.tmux.conf"
    add_symlink "$DIR/tool-integrations/tmux/tmux-small.conf" "$HOME/.tmux-small.conf"
}
