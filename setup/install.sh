#/usr/bin/env bash

mkdir $HOME/tmp
git clone --recurse-submodules https://github.com/pascalweiss/mega-shell-env.git $HOME/tmp/mega
mv $HOME/tmp/mega $HOME/.mega
rm -rf $HOME/tmp/mega

$HOME/.mega/setup/setup.sh