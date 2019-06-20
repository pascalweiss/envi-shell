#!/usr/bin/env bash

source $DIR/install/packages_os.sh

DEBUG=1
DIR="$( cd "$(dirname "$0")/.." ; pwd -P )"

mkdir $HOME/tmp && CD $HOME/tmp

# Do some OS specific preparation
if [[ "$(uname)" = *Darwin* ]]; then
    source $DIR/install/preparation_mac.sh
elif [[ "$(unamme)" = *Linux* ]]; then
    source $DIR/install/preparation_linux.sh
fi
 

# Install OS packages
if (( $DEBUG == 1 )); then
    PACKAGES=(nsnake cask)    
else
    set_packages
fi

install_packages

# Install python packages
pip3 install -r $DIR/install/packages_python.txt

# Install oh-my-zsh
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true

# Install setup zsh and vim
git clone https://github.com/pascalweiss/dotfiles.git $HOME/tmp/dotfiles
mv $HOME/tmp/dotfiles/.zshrc $HOME/.zshrc
mv $HOME/tmp/dotfiles/.vim $HOME/.vim
mv $HOME/tmp/dotfiles/.vimrc $HOME/.vimrc
mv $HOME/tmp/dotfiles/.git $HOME/.git


# Add files to home folder
ln -s $DIR/.mega_env $HOME/.mega_env
ln -s $DIR/.mega_locations $HOME/.mega_locations
ln -s $DIR/.mega_rc $HOME/.mega_rc
ln -s $DIR/.mega_shortcuts $HOME/.mega_shortcuts
cp $DIR/modrc

# Add to rc
if [[ "$SHELL" = *bash* ]]; then
    bash --rcfile $HOME/.mega_rc
elif [[ "$SHELL" = *zsh* ]]; then
    zsh --rcf $HOME/.mega_rc
fi






