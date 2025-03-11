#!/usr/bin/env bash

DIR="$( cd "$(dirname "$0")/.." ; pwd -P )"
SETUP_OS="$DIR/setup/_func_packages_os.sh"
SETUP_PY="$DIR/setup/_func_packages_python.sh"
SETUP_OH_MY_ZSH="$DIR/setup/_func_oh_my_zsh.sh"
SETUP_DOTFILES="$DIR/setup/_func_dotfiles.sh"
ARGS=("${@}")

source "$DIR/setup/_func_preparation.sh"
source "$DIR/executables/bin/commons"

# Variables to store user decisions
CONFIGURE_TIMEZONE=false
UPDATE_PACKAGE_MANAGER=false
INSTALL_DEPENDENCIES=false
INSTALL_OS_PACKAGES=false
INSTALL_PYTHON_PACKAGES=false
INSTALL_OH_MY_ZSH=false
REPLACE_BASHRC=false
REPLACE_ZSHRC=false
REPLACE_VIM=false
REPLACE_GITCONFIG=false

# Collect all decisions upfront
if ! contains "--configure-timezone=no" "${ARGS[@]}"; then
    read -ep "Do you want to configure the timezone? Type (Y/n): " ANSWER
    CONFIGURE_TIMEZONE=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )
fi

if ! contains "--update-package-manager=no" "${ARGS[@]}"; then
    read -ep "Do you want to update the package manager? Type (Y/n): " ANSWER
    UPDATE_PACKAGE_MANAGER=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )
fi

if ! contains "--install-dependencies=no" "${ARGS[@]}"; then
    read -ep "Do you want to install dependencies? Type (Y/n): " ANSWER
    INSTALL_DEPENDENCIES=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )
fi

read -ep "Do you want to install OS packages (config/packages_os.txt)? Type (Y/n): " ANSWER
INSTALL_OS_PACKAGES=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

read -ep "Do you want to install Python packages (config/packages_python.txt)? Type (Y/n): " ANSWER
INSTALL_PYTHON_PACKAGES=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

read -ep "Do you want to install oh-my-zsh? Type (Y/n): " ANSWER
INSTALL_OH_MY_ZSH=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

read -ep "Do you want to replace your .bashrc? Type (Y/n): " ANSWER
REPLACE_BASHRC=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

read -ep "Do you want to replace your .zshrc? Type (Y/n): " ANSWER
REPLACE_ZSHRC=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

read -ep "Do you want to replace your vim configuration? Type (Y/n): " ANSWER
REPLACE_VIM=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

read -ep "Do you want to replace your .gitconfig? Type (Y/n): " ANSWER
REPLACE_GITCONFIG=$( [[ "$ANSWER" =~ ^[Yy]$ || "$ANSWER" == "" ]] && echo true || echo false )

# Execute the decisions
if $CONFIGURE_TIMEZONE; then
    source "$SETUP_OS" && configure_timezone
fi

mkdir -p "$DIR/config"
FILES=($(ls "$DIR/setup/templates"))
for FILE in "${FILES[@]}"; do
    # Copy the template files to the config folder, only if it is not a .md file
    if [[ "$FILE" != *.md ]]; then
        cp "$DIR/setup/templates/$FILE" "$DIR/config/.$FILE"
    fi
done

if $UPDATE_PACKAGE_MANAGER; then
    source "$SETUP_OS"
    update_package_manager
fi

if $INSTALL_DEPENDENCIES; then
    source "$SETUP_OS" && install_dependencies
fi

if $INSTALL_OS_PACKAGES; then
    source "$SETUP_OS" && install_packages
fi

if $INSTALL_PYTHON_PACKAGES; then
    source "$SETUP_OS" && install_python
    source "$SETUP_PY" && install_packages
fi

if $INSTALL_OH_MY_ZSH; then
    source "$SETUP_OS" && install_oh_my_zsh
    source "$SETUP_OH_MY_ZSH" && install_packages
fi

if $REPLACE_BASHRC; then
    source "$SETUP_DOTFILES" && replace_bashrc
fi

if $REPLACE_ZSHRC; then
    source "$SETUP_DOTFILES" && replace_zshrc
fi

if $REPLACE_VIM; then
    source "$SETUP_DOTFILES" && replace_vim
fi

# Later in the execution section
if $REPLACE_GITCONFIG; then
    source "$SETUP_DOTFILES" && replace_gitconfig
fi


add_symlink "$DIR/config/.envi_env" "$HOME/.envi_env"
add_symlink "$DIR/config/.envi_locations" "$HOME/.envi_locations"
add_symlink "$DIR/config/.envi_rc" "$HOME/.envi_rc"
add_symlink "$DIR/config/.envi_shortcuts" "$HOME/.envi_shortcuts"

BIN_DIRS=("bin" "sbin" "lib" "macbin" "linuxbin")
for BIN in "${BIN_DIRS[@]}"; do
    chmod u+x "$DIR/executables/$BIN/"*
done

if $INSTALL_OH_MY_ZSH; then
    chsh --shell "$(command -v zsh)"
    exec zsh
else
    chsh --shell "$(command -v bash)"
    exec bash
fi
