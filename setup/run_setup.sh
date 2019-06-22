#!/usr/bin/env bash

set +e

DIR="$( cd "$(dirname "$0")/.." ; pwd -P )"
SETUP_OS=$DIR/setup/_func_packages_os.sh
SETUP_PY=$DIR/setup/_func_packages_python.sh
SETUP_OH_MY_ZSH=$DIR/setup/_func_oh_my_zsh.sh
SETUP_DOTFILES=$DIR/setup/_func_dotfiles.sh
ARGS=("${@}")

source $DIR/setup/_func_preparation.sh
source $DIR/executables/bin/commons

# Install dependencies
if ! contains "--update_package_manager=no" "${ARGS[@]}"; then 
    source $SETUP_OS && update_package_manager
fi

# Install dependencies
if ! contains "--install-dependencies=no" "${ARGS[@]}"; then 
    source $SETUP_OS && install_dependencies
fi

# Install OS packages
function lambda_os_install () {
    source $SETUP_OS && install_packages
}
install_dialog "--install-os-packages" "--install-os-packages=no" "Do you want to install the OS packages (config/packages_os.txt)? Type (Y/n): " "lambda_os_install" "${ARGS[@]}"

# Install python packages
function lambda_python_install () {
    source $SETUP_OS && install_python
    source $SETUP_PY && install_packages
}
install_dialog "--install-python-packages" "--install-python-packages=no" "Do you want to install the python packages (config/packages_python.txt)? Type (Y/n): " "lambda_python_install" "${ARGS[@]}"

# Install oh-my-zsh
function lambda_oh_my_zsh_install () {
    source $SETUP_OS && install_oh_my_zsh
    source $SETUP_OH_MY_ZSH && install_packages
}
install_dialog "--install-oh-my-zsh" "--install-oh-my-zsh=no" "Do you want to install oh-my-zsh? Type (Y/n): " "lambda_oh_my_zsh_install" "${ARGS[@]}"

# Replace Shell bashrc
function lambda_replace_bashrc () {
    source $SETUP_DOTFILES && replace_bashrc
}
install_dialog "--replace-bashrc" "--replace-bashrc=no" "The next step will backup your .bashrc in ~/dotfiles_backup and replace it with a new one. Do you want this? Type (Y/n): " "lambda_replace_bashrc" "${ARGS[@]}"

# Replace Shell zshrc
function lambda_replace_zshrc () {
    source $SETUP_DOTFILES && replace_zshrc
}
install_dialog "--replace-zshrc" "--replace-zshrc=no" "The next step will backup your .zshrc in ~/dotfiles_backup and replace it with a new one. Do you want this? Type (Y/n): " "lambda_replace_zshrc" "${ARGS[@]}"

# Replace vim config
function lambda_replace_vim () {
    source $SETUP_DOTFILES && replace_vim
}
install_dialog "--replace-vim" "--replace-vim=no" "The next step will backup your .vimrc and .vim in ~/dotfiles_backup and replace them with a new ones. Do you want this? Type (Y/n): " "lambda_replace_vim" "${ARGS[@]}"

# Add files to home folder
add_symlink "$DIR/config/.mega_env" "$HOME/.mega_env"
add_symlink "$DIR/config/.mega_locations" "$HOME/.mega_locations"
add_symlink "$DIR/config/.mega_rc" "$HOME/.mega_rc"
add_symlink "$DIR/config/.mega_shortcuts" "$HOME/.mega_shortcuts"

# Add execution right
BIN_DIRS=("bin" "sbin" "lib" "macbin" "linuxbin")
for BIN in "${BIN_DIRS[@]}"; do 
    chmod u+x "$DIR/executables/$BIN/"*
done


if contains "--install-oh-my-zsh=no" "${ARGS[@]}"; then
    chsh --shell $(command -v zsh)
    exec bash
else 
    chsh --shell $(command -v zsh)
    exec zsh
fi
