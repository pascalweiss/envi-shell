#! /usr/bin/env bash

BLUE='\033[0;34m'
NC='\033[0m' # No Color

mkdir "$HOME"/tmp
echo -e "${BLUE}Cloning envi-shell${NC}"
git clone --recurse-submodules https://github.com/pascalweiss/envi-shell.git "$HOME"/tmp/envi
mv "$HOME"/tmp/envi "$HOME"/.envi
rm -rf "$HOME"/tmp/envi

"$HOME"/.envi/setup/run_setup.sh
