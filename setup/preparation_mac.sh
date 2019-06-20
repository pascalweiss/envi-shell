#! /usr/bin/bash

# Combine the tools for mac 
function set_packages() {
    PACKAGES=("${PACKAGES_DEFAULT[@]}" "${PACKAGES_MAC[@]}" "${PACKAGES_PYTHON[@]}")
}

function install_packages() {
    if [ ! `command -v brew` ]; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
    brew install $PACKAGES
}
