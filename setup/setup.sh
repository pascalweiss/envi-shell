#!/usr/bin/env bash

set +e

DIR="$( cd "$(dirname "$0")/.." ; pwd -P )"

source $DIR/setup/install_packages.sh
source $DIR/setup/replace_dotfiles.sh
source $DIR/executables/bin/commons

# Install dependencies
if ! contains "--install-dependencies=no" "$@"; then os_dependencies_install; fi

# Do some OS specific preparation
if contains "--install-os-packages" "$@"; then os_packages_install;
elif contains "--install-os-packages=no" "$@" ; then :
else 
    read -ep "Do you want to install the OS packages (config/packages_os.txt)? Type (Y/n): " ANSWER
    if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then os_packages_install; fi
fi

# Install python packages
if contains "--install-python-packages" "$@"; then python_packages_install; 
elif contains "--install-python-packages=no" "$@"; then :
else 
    read -ep "Do you want to install the python packages (config/packages_python.txt)? Type (Y/n): " ANSWER
    if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then python_packages_install; fi
fi

# Install oh-my-zsh
if contains "--install-oh-my-zsh" "$@"; then install_oh_my_zsh; 
elif contains "--install-oh-my-zsh=no" "$@"; then :
else 
    read -ep "Do you want to install oh-my-zsh? Type (Y/n): " ANSWER
    if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then  oh_my_zsh_install; fi
fi

# Replace Shell rc files
if contains "--replace-bashrc" "$@"; then replace_bashrc; 
elif contains "--replace-bashrc=no" "$@"; then :
else
    read -ep "The next step will backup your .bashrc in ~/dotfiles_backup and replace it with a new one. Do you want this? Type (Y/n): " ANSWER
    if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then replace_bashrc; fi
fi
if contains "--replace-zshrc" "$@"; then replace_bashrc; 
elif contains "--replace-zshrc=no" "$@"; then :
else
    read -ep "The next step will backup your .zshrc in ~/dotfiles_backup and replace it with a new one. Do you want this? Type (Y/n): " ANSWER
    if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then replace_zshrc; fi
fi

# Replace vim config
if contains "--replace-vim" "$@"; then replace_bashrc; 
elif contains "--replace-vim=no" "$@"; then :
else
    read -ep "The next step will backup your .vimrc and .vim in ~/dotfiles_backup and replace them with a new ones. Do you want this? Type (Y/n) :" ANSWER
    if [[ "$ANSWER" = [Yy] || "$ANSWER" = "" ]]; then replace_vim; fi
fi

# Add files to home folder
add_symlink "$DIR/.mega_env" "$HOME/.mega_env"
add_symlink "$DIR/.mega_locations" "$HOME/.mega_locations"
add_symlink "$DIR/.mega_rc" "$HOME/.mega_rc"
add_symlink "$DIR/.mega_shortcuts" "$HOME/.mega_shortcuts"

# Add execution right
BIN_DIRS=("bin" "sbin" "lib" "macbin" "linuxbin")
for BIN in "${BIN_DIRS[@]}"; do 
    chmod u+x "$DIR/executables/$BIN/"*
done

if [[ "$SHELL" = *bash* ]]; then
    exec bash
elif [[ "$SHELL" = *zsh* ]]; then
    exec zsh
fi

