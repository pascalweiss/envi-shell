#/usr/bin/env bash

mkdir $HOME/tmp
git clone https://github.com/pascalweiss/mega-shell-env.git $HOME/tmp/mega
mv $HOME/tmp/mega .mega

source $HOME/.mega/setup/setup.sh