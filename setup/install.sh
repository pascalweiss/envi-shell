#! /usr/bin/env bash

source "$DIR"/setup/_func_console_output.sh

mkdir "$HOME"/tmp
echo -e "${YELLOW}Cloning envi-shell${NC}"
git clone --recurse-submodules https://github.com/pascalweiss/envi-shell.git "$HOME"/tmp/envi
mv "$HOME"/tmp/envi "$HOME"/.envi
rm -rf "$HOME"/tmp/envi

"$HOME"/.envi/setup/run_setup.sh
