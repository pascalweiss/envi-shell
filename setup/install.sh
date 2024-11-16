#! /usr/bin/env bash

mkdir $HOME/tmp
git clone --recurse-submodules https://github.com/pascalweiss/mega-shell-env.git $HOME/tmp/envi
mv $HOME/tmp/envi $HOME/.envi
rm -rf $HOME/tmp/envi

$HOME/.envi/setup/run_setup.sh